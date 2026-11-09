import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../shared/ui_contract_core/theme/contract_grid_scaled_row.dart';
import '../shared/ui_contract_core/theme/anchored_action_slot.dart';
import 'logistics_gps_reconciliation.dart';
import 'logistics_gps_visit_store.dart';
import 'logistics_gps_curation_store.dart';
import 'logistics_gps_trash_widgets.dart';
import 'logistics_theme.dart';

// Assignment workflow: Services/Entradas-Salidas grid footprint and Logistics
// tokens, with one selected destination (batch assignment is intentionally absent).
class LogisticsGpsReconciliationPanel extends StatefulWidget {
  final LogisticsGpsVisitBundle bundle;
  final GpsCuration curation;
  final DateTime now;
  final bool active, sourceFresh;
  final Future<List<GpsDailyService>> Function(DateTime) loadServices;
  final Future<void> Function()? onChanged;
  final Future<void> Function(String, String?, String?, String) saveAssignment;
  const LogisticsGpsReconciliationPanel({
    super.key,
    required this.bundle,
    required this.now,
    required this.active,
    required this.sourceFresh,
    this.curation = const GpsCuration(),
    this.onChanged,
    this.loadServices = GpsDailyServiceStore.load,
    this.saveAssignment = GpsCurationStore.assign,
  });
  @override
  State<LogisticsGpsReconciliationPanel> createState() => _AssignmentState();
}

class _AssignmentState extends State<LogisticsGpsReconciliationPanel> {
  final _search = TextEditingController(),
      _visitSearch = TextEditingController();
  final _scroll = ScrollController(), _horizontal = ScrollController();
  final _focus = FocusNode();
  late DateTime _day;
  List<GpsDailyService>? _services;
  String? _error, _selectedId, _busyId;
  String _filter = 'Todos';
  bool _compatibleOnly = true, _dragging = false, _deferred = false;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _day = gpsOperationalDay(widget.now);
    if (widget.active) unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant LogisticsGpsReconciliationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && (!oldWidget.active || oldWidget.now != widget.now)) {
      if (_busyId != null || _dragging) {
        _deferred = true;
      } else {
        unawaited(_load());
      }
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    try {
      final services = await widget.loadServices(_day);
      if (!mounted || request != _request) return;
      setState(() {
        _services = services;
        _error = null;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _services = null;
        _error =
            'No se pudo consultar Control Diario. Se reintentará automáticamente.';
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _visitSearch.dispose();
    _scroll.dispose();
    _horizontal.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<GpsDailyService> get _daily =>
      (_services ?? [])
          .where(
            (s) =>
                gpsDayKey(s.day) == gpsDayKey(_day) &&
                s.status != 'completado' &&
                ((s.status != 'cancelado' && !isDicsaCelaya(s.company)) ||
                    widget.curation.forService(s.id) != null),
          )
          .toList()
        ..sort((a, b) {
          final hour = a.scheduledTime.compareTo(b.scheduledTime);
          return hour != 0 ? hour : a.id.compareTo(b.id);
        });
  List<GpsDailyService> get _visible => _daily
      .where(
        (s) =>
            (_filter == 'Todos' ||
                (_filter == 'Asignados') ==
                    (widget.curation.forService(s.id) != null)) &&
            '${s.unit} ${s.company} ${s.direction} ${s.notes}'
                .toUpperCase()
                .contains(_search.text.trim().toUpperCase()),
      )
      .toList();
  GpsDailyService? get _selected =>
      _visible.where((s) => s.id == _selectedId).firstOrNull;
  List<LogisticsGpsVisit> get _available =>
      widget.bundle.visits
          .where(
            (v) =>
                v.visibleInVisitLog &&
                gpsVisitOnDay(v, _day) &&
                !widget.curation.hidden('visit', v.id) &&
                !widget.curation.assigned(v.id),
          )
          .toList()
        ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  List<LogisticsGpsVisit> get _visits {
    final service = _selected;
    return _available
        .where(
          (v) =>
              (!_compatibleOnly ||
                  service == null ||
                  gpsVisitFitsService(service, v)) &&
              '${v.unitLabel} ${v.placeLabel}'.toUpperCase().contains(
                _visitSearch.text.trim().toUpperCase(),
              ),
        )
        .toList();
  }

  Future<void> _changeDay(DateTime day) async {
    if (_busyId != null || _dragging) return;
    setState(() {
      _day = day;
      _services = null;
      _error = null;
      _selectedId = null;
    });
    await _load();
  }

  Future<void> _pickDay() async {
    final today = gpsOperationalDay(widget.now),
        first = gpsOperationalDay(
          widget.now,
        ).subtract(const Duration(days: 29));
    final picked = await showDatePicker(
      context: context,
      initialDate: _day.isBefore(first) ? today : _day,
      firstDate: first,
      lastDate: today,
    );
    if (picked != null && mounted) {
      await _changeDay(DateTime.utc(picked.year, picked.month, picked.day));
    }
  }

  bool _canAssign(GpsDailyService service, LogisticsGpsVisit visit) =>
      widget.curation.available &&
      _services != null &&
      _error == null &&
      _busyId == null &&
      widget.curation.forService(service.id) == null &&
      !widget.curation.assigned(visit.id) &&
      !widget.curation.hidden('visit', visit.id) &&
      gpsVisitFitsService(service, visit);
  Future<void> _assign(GpsDailyService service, LogisticsGpsVisit visit) async {
    if (!_canAssign(service, visit)) return;
    // Capture concurrency token before any dialog. Refresh defers during review.
    final expected = widget.curation.forService(service.id)?.id;
    setState(() => _busyId = service.id);
    String note = '';
    try {
      if (visit.hasGap || visit.status == 'interrupted') {
        final reason = await gpsReviewReason(
          context,
          'Asignar visita con interrupciones',
          '${service.unit} · ${service.company}\nEl GPS no demuestra permanencia continua. Indica por qué corresponde a este servicio.',
        );
        if (reason == null || !mounted) return;
        note = reason;
      }
      await widget.saveAssignment(service.id, visit.id, expected, note);
      await _load();
      await widget.onChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visita asignada y servicio completado.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(gpsWriteError(e))));
      }
      await widget.onChanged?.call();
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
        if (_deferred) {
          _deferred = false;
          unawaited(_load());
        }
      }
    }
  }

  Future<void> _unassign(
    GpsDailyService service,
    GpsAssignment assignment,
  ) async {
    if (_busyId != null) return;
    setState(() => _busyId = service.id);
    try {
      await widget.saveAssignment(service.id, null, assignment.id, '');
      await widget.onChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(gpsWriteError(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
        if (_deferred) {
          _deferred = false;
          unawaited(_load());
        }
      }
    }
  }

  String _time(DateTime time) {
    final t = time.toUtc().subtract(const Duration(hours: 6));
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String _interval(LogisticsGpsVisit visit) =>
      '${_time(visit.startedAt)} → ${visit.endedAt == null ? 'Abierta' : _time(visit.endedAt!)}';
  void _select(GpsDailyService service) {
    _focus.requestFocus();
    setState(() => _selectedId = service.id);
  }

  @override
  Widget build(BuildContext context) {
    final today = gpsOperationalDay(widget.now), rows = _visible;
    final assigned = _daily
        .where((s) => widget.curation.forService(s.id) != null)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              tooltip: 'Día anterior',
              onPressed:
                  _busyId == null &&
                      _day.isAfter(today.subtract(const Duration(days: 29)))
                  ? () => _changeDay(_day.subtract(const Duration(days: 1)))
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            OutlinedButton.icon(
              onPressed: _busyId == null ? _pickDay : null,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(gpsDayKey(_day)),
            ),
            IconButton(
              tooltip: 'Día siguiente',
              onPressed: _busyId == null && _day.isBefore(today)
                  ? () => _changeDay(_day.add(const Duration(days: 1)))
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
            TextButton(
              onPressed: _busyId == null ? () => _changeDay(today) : null,
              child: const Text('Hoy'),
            ),
            TextButton(
              onPressed: _busyId == null
                  ? () => _changeDay(today.subtract(const Duration(days: 1)))
                  : null,
              child: const Text('Ayer'),
            ),
            SizedBox(
              width: 250,
              child: TextField(
                key: const ValueKey('reconciliation-search'),
                controller: _search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar servicio, empresa o unidad',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final filter in ['Todos', 'Sin asignar', 'Asignados'])
              ChoiceChip(
                label: Text(
                  '$filter (${filter == 'Todos'
                      ? _daily.length
                      : filter == 'Asignados'
                      ? assigned
                      : _daily.length - assigned})',
                ),
                selected: _filter == filter,
                onSelected: (_) => setState(() => _filter = filter),
              ),
            Text('${_available.length} visitas disponibles'),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Selecciona un servicio y asigna una visita, o arrástrala a su fila. Al asignar una visita, el servicio se completa en Control Diario y sale de esta lista.',
          style: TextStyle(color: kLogisticsSilverTextSecondary, fontSize: 12),
        ),
        if (!widget.curation.available)
          const Text(
            'Asignación y papelera pendientes de habilitar en el servidor.',
            style: TextStyle(color: kLogisticsGpsWarning),
          ),
        if (!widget.sourceFresh || !widget.bundle.isLive(widget.now))
          const Text(
            'GPS sin actualización reciente. Se muestra el historial disponible.',
            style: TextStyle(color: kLogisticsGpsWarning),
          ),
        const SizedBox(height: 10),
        Expanded(
          child: _services == null
              ? Center(
                  child: _error != null
                      ? Text(_error!)
                      : widget.active
                      ? const CircularProgressIndicator()
                      : const SizedBox.shrink(),
                )
              : LayoutBuilder(
                  builder: (context, size) {
                    if (size.maxWidth < 1100) {
                      return Column(
                        children: [
                          Expanded(flex: 5, child: _table(rows)),
                          const SizedBox(height: 10),
                          Expanded(flex: 4, child: _visitPanel()),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _table(rows)),
                        const SizedBox(width: 12),
                        SizedBox(width: 330, child: _visitPanel()),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _cell(String text, double width, {bool bold = false}) => SizedBox(
    width: width,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
        ),
      ),
    ),
  );
  Widget _table(List<GpsDailyService> rows) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Servicios de Control Diario',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: LayoutBuilder(
          builder: (context, size) {
            final width = size.maxWidth < 760 ? 760.0 : size.maxWidth;
            return Scrollbar(
              controller: _horizontal,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontal,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  child: Column(
                    children: [
                      Card(
                        color: kLogisticsSilverSurfaceElevated,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: ContractGridScaledRow(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _cell('HORA', 60, bold: true),
                                _cell('EMPRESA / SERVICIO', 190, bold: true),
                                _cell('UNIDAD', 70, bold: true),
                                _cell('ESTADO', 90, bold: true),
                                _cell('VISITA GPS', 190, bold: true),
                                _cell('ASIGNACIÓN', 128, bold: true),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: rows.isEmpty
                            ? const Center(
                                child: Text(
                                  'No hay servicios con estos filtros.',
                                ),
                              )
                            : Focus(
                                focusNode: _focus,
                                onKeyEvent: (_, event) {
                                  if (event is! KeyDownEvent) {
                                    return KeyEventResult.ignored;
                                  }
                                  if (event.logicalKey ==
                                      LogicalKeyboardKey.escape) {
                                    setState(() => _selectedId = null);
                                    return KeyEventResult.handled;
                                  }
                                  if (![
                                    LogicalKeyboardKey.arrowUp,
                                    LogicalKeyboardKey.arrowDown,
                                  ].contains(event.logicalKey)) {
                                    return KeyEventResult.ignored;
                                  }
                                  final current = rows.indexWhere(
                                    (s) => s.id == _selectedId,
                                  );
                                  final next =
                                      (current +
                                              (event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .arrowDown
                                                  ? 1
                                                  : -1))
                                          .clamp(0, rows.length - 1);
                                  setState(() => _selectedId = rows[next].id);
                                  if (_scroll.hasClients) {
                                    _scroll.animateTo(
                                      (next * 82.0).clamp(
                                        0,
                                        _scroll.position.maxScrollExtent,
                                      ),
                                      duration: const Duration(
                                        milliseconds: 120,
                                      ),
                                      curve: Curves.easeOut,
                                    );
                                  }
                                  return KeyEventResult.handled;
                                },
                                child: ListView.builder(
                                  controller: _scroll,
                                  itemExtent: 82,
                                  itemCount: rows.length,
                                  itemBuilder: (_, i) => _serviceRow(rows[i]),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
  Widget _serviceRow(GpsDailyService service) {
    final assignment = widget.curation.forService(service.id);
    final visit = assignment == null
        ? null
        : widget.bundle.visits
                  .where((v) => v.id == assignment.visitId)
                  .firstOrNull ??
              assignment.visit;
    final stale = visit != null && !gpsVisitFitsService(service, visit);
    return DragTarget<LogisticsGpsVisit>(
      key: ValueKey('drop-${service.id}'),
      onWillAcceptWithDetails: (d) => _canAssign(service, d.data),
      onAcceptWithDetails: (d) {
        _select(service);
        unawaited(_assign(service, d.data));
      },
      builder: (context, accepted, rejected) {
        final active = _selectedId == service.id || accepted.isNotEmpty;
        return Card(
          color: active
              ? kLogisticsSilverSurfaceInteractive
              : kLogisticsSilverSurfaceTop,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: active
                  ? kLogisticsSilverTextPrimary
                  : kLogisticsSilverBorder,
              width: accepted.isNotEmpty ? 2 : 1,
            ),
          ),
          child: InkWell(
            key: ValueKey('reconciliation-service-${service.id}'),
            onTap: () => _select(service),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: ContractGridScaledRow(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _cell(
                      service.scheduledTime.isEmpty
                          ? '—'
                          : service.scheduledTime.substring(0, 5),
                      60,
                    ),
                    Tooltip(
                      message: service.notes.isEmpty
                          ? service.company
                          : '${service.company}\n${service.notes}',
                      child: _cell(
                        '${service.company}\n${service.direction}',
                        190,
                        bold: true,
                      ),
                    ),
                    _cell(service.unit, 70),
                    _cell(service.status, 90),
                    _cell(
                      visit == null
                          ? accepted.isNotEmpty
                                ? 'Soltar para asignar'
                                : 'Arrastra una visita aquí'
                          : '${_interval(visit)}\n${visit.durationLabel}',
                      190,
                    ),
                    AnchoredActionSlot(
                      width: 128,
                      trailingWidth: assignment == null ? 0 : 36,
                      leading: assignment == null
                          ? TextButton(
                              onPressed: () => _select(service),
                              child: Text(
                                _busyId == service.id
                                    ? 'Guardando…'
                                    : 'Elegir visita',
                              ),
                            )
                          : Text(
                              stale ? 'Revisar cambios' : 'Asignada',
                              style: TextStyle(
                                fontSize: 12,
                                color: stale
                                    ? kLogisticsGpsWarning
                                    : kLogisticsSilverTextPrimary,
                              ),
                            ),
                      trailing: assignment == null
                          ? null
                          : IconButton(
                              key: ValueKey('unassign-${service.id}'),
                              tooltip: 'Quitar asignación',
                              onPressed:
                                  _busyId == null && widget.curation.available
                                  ? () => _unassign(service, assignment)
                                  : null,
                              icon: const Icon(Icons.link_off),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _visitPanel() {
    final service = _selected, visits = _visits;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          service == null
              ? 'Visitas GPS disponibles'
              : 'Visitas para ${service.unit} · ${service.company}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        TextField(
          key: const ValueKey('assignment-visit-search'),
          controller: _visitSearch,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Buscar visita',
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (service != null)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: _compatibleOnly,
            onChanged: (v) => setState(() => _compatibleOnly = v!),
            title: const Text('Sólo compatibles'),
          ),
        Expanded(
          child: visits.isEmpty
              ? const Center(
                  child: Text('No hay visitas disponibles con estos filtros.'),
                )
              : ListView.builder(
                  itemCount: visits.length,
                  itemBuilder: (context, i) {
                    final v = visits[i];
                    final canDrag =
                        widget.curation.available && _busyId == null;
                    final card = _visitCard(v, service);
                    return Draggable<LogisticsGpsVisit>(
                      key: ValueKey('drag-${v.id}'),
                      data: v,
                      maxSimultaneousDrags: canDrag ? 1 : 0,
                      onDragStarted: () => setState(() => _dragging = true),
                      onDragEnd: (_) {
                        setState(() => _dragging = false);
                        if (_deferred && _busyId == null) {
                          _deferred = false;
                          unawaited(_load());
                        }
                      },
                      feedback: Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 300,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              '${v.unitLabel} · ${v.placeLabel}\n${_interval(v)}',
                            ),
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(opacity: .4, child: card),
                      child: card,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _visitCard(LogisticsGpsVisit visit, GpsDailyService? service) => Card(
    color: kLogisticsSilverSurfaceTop,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.drag_indicator, color: kLogisticsSilverIcon),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${visit.unitLabel} · ${visit.placeLabel}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          Text('${_interval(visit)} · ${visit.durationLabel}'),
          if (visit.hasGap || visit.status == 'interrupted')
            const Text(
              'GPS con interrupciones',
              style: TextStyle(color: kLogisticsGpsWarning),
            ),
          Wrap(
            spacing: 4,
            children: [
              FilledButton.tonal(
                key: ValueKey('assign-${visit.id}'),
                onPressed: service != null && _canAssign(service, visit)
                    ? () => _assign(service, visit)
                    : null,
                child: const Text('Asignar'),
              ),
              GpsTrashButton(
                kind: 'visit',
                eventId: visit.id,
                label: '${visit.unitLabel} · ${visit.placeLabel}',
                enabled: widget.curation.available && _busyId == null,
                onChanged: widget.onChanged ?? () async {},
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
