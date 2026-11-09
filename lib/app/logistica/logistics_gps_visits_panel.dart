import 'logistics_gps_curation_store.dart';
import 'logistics_gps_trash_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'logistics_gps_visit_store.dart';
import 'logistics_theme.dart';

// Read-only Workflow Master-Detail, matching the Logistics incident workspace.
class LogisticsGpsVisitsPanel extends StatefulWidget {
  final GpsCuration curation;
  final Future<void> Function()? onChanged;
  final LogisticsGpsVisitBundle bundle;
  final DateTime now;
  final bool sourceFresh;
  const LogisticsGpsVisitsPanel({
    super.key,
    this.curation = const GpsCuration(),
    this.onChanged,
    required this.bundle,
    required this.now,
    this.sourceFresh = true,
  });
  @override
  State<LogisticsGpsVisitsPanel> createState() =>
      _LogisticsGpsVisitsPanelState();
}

class _LogisticsGpsVisitsPanelState extends State<LogisticsGpsVisitsPanel> {
  final _search = TextEditingController(), _scroll = ScrollController();
  final _focus = FocusNode();
  String _filter = 'Todas', _period = '7 días';
  String? _selectedId;
  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<LogisticsGpsVisit> get _visible {
    final query = _search.text.trim().toUpperCase();
    final local = widget.now.toLocal();
    final since = _period == 'Hoy'
        ? DateTime(local.year, local.month, local.day).toUtc()
        : widget.now.subtract(Duration(days: _period == '7 días' ? 7 : 30));
    return widget.bundle.visits
        .where(
          (v) =>
              !widget.curation.hidden('visit', v.id) &&
              v.visibleInVisitLog &&
              (v.status == 'open' || !v.startedAt.isBefore(since)) &&
              '${v.unitLabel} ${v.placeLabel} ${v.geofenceName}'
                  .toUpperCase()
                  .contains(query) &&
              switch (_filter) {
                'Abiertas' => v.status == 'open',
                'Con salida' => v.status == 'closed',
                'Interrumpidas' => v.status == 'interrupted',
                _ => true,
              },
        )
        .toList();
  }

  LogisticsGpsVisit? get _selected =>
      _visible.where((v) => v.id == _selectedId).firstOrNull ??
      _visible.firstOrNull;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              key: const ValueKey('visits-search'),
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar unidad o empresa',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          _dropdown('Periodo', _period, [
            'Hoy',
            '7 días',
            '30 días',
          ], (v) => setState(() => _period = v)),
          _dropdown('Mostrar', _filter, [
            'Todas',
            'Abiertas',
            'Con salida',
            'Interrumpidas',
          ], (v) => setState(() => _filter = v)),
          Text('${_visible.length} visitas'),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        'Solo visitas de 5 minutos o más · Horas aproximadas por GPS · Incluye visitas abiertas de días anteriores.',
        style: const TextStyle(
          fontSize: 12,
          color: kLogisticsSilverTextSecondary,
        ),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: LayoutBuilder(
          builder: (context, size) {
            if (size.maxWidth < 850) {
              return Column(
                children: [
                  SizedBox(height: size.maxHeight * .40, child: _list()),
                  const SizedBox(height: 8),
                  Expanded(child: _detail()),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 340, child: _list()),
                const SizedBox(width: 14),
                Expanded(child: _detail()),
              ],
            );
          },
        ),
      ),
    ],
  );
  Widget _dropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String> change,
  ) => SizedBox(
    width: 175,
    child: DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
          .toList(),
      onChanged: (v) {
        if (v != null) change(v);
      },
    ),
  );
  Widget _list() {
    final visits = _visible;
    if (visits.isEmpty) {
      return const Center(
        child: Text(
          'Aún no hay visitas con estos filtros.\nSe registrarán al confirmar nuevas posiciones.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return Focus(
      focusNode: _focus,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent ||
            ![
              LogicalKeyboardKey.arrowDown,
              LogicalKeyboardKey.arrowUp,
            ].contains(event.logicalKey)) {
          return KeyEventResult.ignored;
        }
        final current = visits.indexWhere((v) => v.id == _selected?.id);
        final next =
            (current +
                    (event.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1))
                .clamp(0, visits.length - 1);
        setState(() => _selectedId = visits[next].id);
        if (_scroll.hasClients) {
          _scroll.animateTo(
            (next * 110.0).clamp(0, _scroll.position.maxScrollExtent),
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
          );
        }
        return KeyEventResult.handled;
      },
      child: ListView.builder(
        controller: _scroll,
        itemExtent: 110,
        itemCount: visits.length,
        itemBuilder: (context, index) {
          final v = visits[index], selected = v.id == _selected?.id;
          return Card(
            clipBehavior: Clip.antiAlias,
            color: selected
                ? kLogisticsSilverSurfaceInteractive
                : kLogisticsSilverSurfaceTop,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: selected
                    ? kLogisticsSilverTextPrimary
                    : kLogisticsSilverBorder,
              ),
            ),
            child: ListTile(
              key: ValueKey('visit-${v.id}'),
              onTap: () {
                _focus.requestFocus();
                setState(() => _selectedId = v.id);
              },
              leading: Icon(
                v.status == 'closed'
                    ? Icons.logout
                    : v.status == 'interrupted'
                    ? Icons.location_off_outlined
                    : Icons.location_on_outlined,
                color: v.hasGap ? kLogisticsGpsWarning : kLogisticsSilverIcon,
              ),
              title: Text(
                '${v.unitLabel} · ${v.placeLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${v.statusLabel}\n${gpsVisitDate(v.startedAt)}',
                maxLines: 2,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _detail() {
    final v = _selected;
    return Card(
      color: kLogisticsSilverSurfaceTop,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: kLogisticsSilverBorder),
      ),
      child: v == null
          ? const Center(
              child: Text('Selecciona una visita para ver sus tiempos.'),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${v.unitLabel} · ${v.placeLabel}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  GpsTrashButton(
                    kind: 'visit',
                    eventId: v.id,
                    label: '${v.unitLabel} · ${v.placeLabel}',
                    enabled:
                        widget.curation.available &&
                        !widget.curation.assigned(v.id),
                    onChanged: widget.onChanged ?? () async {},
                  ),
                  if (widget.curation.assigned(v.id))
                    const Text(
                      'Visita asignada: quita la asignación en Asignación para enviarla a papelera.',
                    ),
                  const SizedBox(height: 6),
                  Text(
                    '${v.classification == 'base' ? 'Base DICSA' : 'Empresa'} · ${v.geofenceName}',
                  ),
                  const SizedBox(height: 20),
                  _fact('Estado', v.statusLabel),
                  _fact(v.arrivalLabel, gpsVisitDate(v.startedAt)),
                  if (v.arrivalKind == 'first_seen')
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'La unidad ya estaba dentro al iniciar o retomar el seguimiento. La hora real de llegada no se observó.',
                        style: TextStyle(color: kLogisticsSilverTextSecondary),
                      ),
                    ),
                  _fact('Última posición dentro', gpsVisitDate(v.lastInsideAt)),
                  _fact(
                    'Salida aproximada',
                    v.endedAt == null
                        ? 'Sin salida confirmada'
                        : gpsVisitDate(v.endedAt),
                  ),
                  _fact('Tiempo de estancia', v.durationLabel),
                  if (v.minimumDwellSeconds < 300)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Registro anterior: se confirmó con la regla de 1 minuto.',
                      ),
                    ),
                  if (v.status == 'open' &&
                      widget.bundle.visits
                              .where(
                                (other) =>
                                    other.unitId == v.unitId &&
                                    other.status == 'open',
                              )
                              .length >
                          1)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'La unidad coincide con más de una geocerca. Revisa los límites antes de atribuir la visita a una empresa.',
                        style: TextStyle(color: kLogisticsGpsWarning),
                      ),
                    ),
                  if (v.status == 'open')
                    Text(
                      widget.bundle.location(
                        v.unitId,
                        widget.now,
                        sourceFresh: widget.sourceFresh,
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  if (v.hasGap)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text(
                        'Hubo una interrupción del seguimiento. El intervalo completo no demuestra permanencia continua.',
                        style: TextStyle(color: kLogisticsGpsWarning),
                      ),
                    ),
                  if (v.status == 'interrupted')
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text(
                        'Cambió la geocerca, su vínculo o la disponibilidad de la unidad. La visita se conservó sin inventar una salida.',
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _fact(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: kLogisticsSilverTextSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
