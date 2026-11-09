import 'logistics_gps_curation_store.dart';
import 'logistics_gps_trash_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'logistics_gps_visit_store.dart' show gpsVisitDate;
import 'logistics_gps_stop_store.dart';
import 'logistics_geofence_store.dart';
import 'logistics_geofence_widgets.dart';
import 'logistics_area_chrome.dart';
import 'logistics_theme.dart';

// Read-only Workflow Master-Detail, matching the Logistics incident workspace.
class LogisticsGpsStopsPanel extends StatefulWidget {
  final GpsCuration curation;
  final LogisticsGpsStopBundle bundle;
  final DateTime now;
  final List<LogisticsGeofence> geofences;
  final Future<void> Function() onChanged;
  final bool sourceFresh;
  const LogisticsGpsStopsPanel({
    super.key,
    this.curation = const GpsCuration(),
    required this.bundle,
    required this.now,
    required this.geofences,
    required this.onChanged,
    this.sourceFresh = true,
  });
  @override
  State<LogisticsGpsStopsPanel> createState() => _LogisticsGpsStopsPanelState();
}

class _LogisticsGpsStopsPanelState extends State<LogisticsGpsStopsPanel> {
  final _search = TextEditingController(), _scroll = ScrollController();
  final _focus = FocusNode();
  String _filter = 'Pendientes', _period = '7 días';
  String? _selectedId;
  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<LogisticsGpsStop> get _visible {
    final query = _search.text.trim().toUpperCase();
    final local = widget.now.toLocal();
    final since = _period == 'Hoy'
        ? DateTime(local.year, local.month, local.day).toUtc()
        : widget.now.subtract(Duration(days: _period == '7 días' ? 7 : 30));
    return widget.bundle.stops
        .where(
          (v) =>
              !widget.curation.hidden('stop', v.id) &&
              (v.status == 'open' || !v.startedAt.isBefore(since)) &&
              '${v.unitLabel} ${v.reviewNote ?? ''} ${v.coordinates}'
                  .toUpperCase()
                  .contains(query) &&
              switch (_filter) {
                'Pendientes' => !v.reviewed,
                'Revisadas' => v.reviewed,
                _ => true,
              },
        )
        .toList();
  }

  LogisticsGpsStop? get _selected =>
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
              key: const ValueKey('stops-search'),
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar unidad o motivo',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          _dropdown('Periodo', _period, [
            'Hoy',
            '7 días',
            '30 días',
          ], (v) => setState(() => _period = v)),
          _dropdown('Revisión', _filter, [
            'Pendientes',
            'Revisadas',
            'Todas',
          ], (v) => setState(() => _filter = v)),
          Text(
            '${_visible.length} ${_visible.length == 1 ? 'parada' : 'paradas'}',
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        'Paradas de al menos 5 minutos fuera de geocercas · Registro desde ${gpsVisitDate(widget.bundle.enabledAt)} · Horas aproximadas.',
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
          'Aún no hay paradas con estos filtros.\nSe registrarán al confirmar 5 minutos con nuevas posiciones GPS.',
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
              key: ValueKey('stop-${v.id}'),
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
                color: v.status == 'interrupted'
                    ? kLogisticsGpsWarning
                    : kLogisticsSilverIcon,
              ),
              title: Text(
                '${v.unitLabel} · ${v.reviewed ? 'Revisada' : 'Pendiente'}',
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
    final stop = _selected;
    return Card(
      color: kLogisticsSilverSurfaceTop,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: kLogisticsSilverBorder),
      ),
      child: stop == null
          ? const Center(
              child: Text('Selecciona una parada para revisar su ubicación.'),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${stop.unitLabel} · Parada sin geocerca',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Fuera de las geocercas disponibles cuando se detectó. El GPS no determina el motivo.',
                  ),
                  const SizedBox(height: 20),
                  _fact('Estado', stop.statusLabel),
                  _fact(
                    'Primera detección detenida',
                    gpsVisitDate(stop.startedAt),
                  ),
                  _fact(
                    'Última posición detenida',
                    gpsVisitDate(stop.lastStationaryAt),
                  ),
                  _fact('Tiempo observado', stop.durationLabel),
                  if (stop.endedAt != null)
                    _fact('Fin aproximado', gpsVisitDate(stop.endedAt)),
                  if (stop.status != 'open')
                    _fact('Fin del seguimiento', stop.endLabel),
                  if (stop.status == 'interrupted')
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'No se conoce el tiempo total de la parada ni su salida. Se conserva únicamente lo observado.',
                        style: TextStyle(color: kLogisticsGpsWarning),
                      ),
                    ),
                  if (stop.status == 'open' &&
                      (!widget.sourceFresh ||
                          !widget.bundle.isLive(widget.now) ||
                          widget.now.difference(stop.lastStationaryAt) >
                              const Duration(minutes: 15)))
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'No se puede confirmar que siga detenida con los datos actuales.',
                        style: TextStyle(color: kLogisticsGpsWarning),
                      ),
                    ),
                  _fact('Ubicación de la parada', stop.coordinates),
                  GpsTrashButton(
                    kind: 'stop',
                    eventId: stop.id,
                    label: '${stop.unitLabel} · ${stop.coordinates}',
                    enabled: widget.curation.available,
                    onChanged: widget.onChanged,
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showMap(stop),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Ver en mapa'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _copy(stop),
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Copiar coordenadas'),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Si es un lugar habitual, usa esta ubicación para crear la geocerca en EPCOM. Aparecerá al sincronizar.',
                    ),
                  ),
                  _fact(
                    'Revisión',
                    stop.reviewed
                        ? 'Revisada · ${gpsVisitDate(stop.reviewedAt)}'
                        : 'Pendiente de revisar',
                  ),
                  if (stop.reviewNote != null)
                    _fact('Motivo o nota', stop.reviewNote!),
                  FilledButton.icon(
                    onPressed: () => _review(stop),
                    icon: const Icon(Icons.edit_note),
                    label: Text(
                      stop.reviewed ? 'Editar revisión' : 'Revisar parada',
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _copy(LogisticsGpsStop stop) async {
    await Clipboard.setData(ClipboardData(text: stop.coordinates));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Coordenadas copiadas')));
    }
  }

  Future<void> _review(LogisticsGpsStop stop) async {
    final saved = await showLogisticsContractDialog<bool>(
      context: context,
      builder: (_) => _StopReviewDialog(stop: stop),
    );
    if (saved == true && mounted) {
      await widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Revisión guardada')));
      }
    }
  }

  Future<void> _showMap(
    LogisticsGpsStop stop,
  ) => showLogisticsContractDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: kLogisticsSilverSurfaceTop,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 900,
        height: MediaQuery.sizeOf(context).height * .8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${stop.unitLabel} · Parada del ${gpsVisitDate(stop.startedAt)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar mapa de parada',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                '${stop.coordinates} · Punto observado; las geocercas del mapa son las actuales.',
              ),
            ),
            Expanded(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(stop.latitude, stop.longitude),
                  initialZoom: 16,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.dicsa.operacion',
                  ),
                  LogisticsGeofenceLayer(fences: widget.geofences),
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: LatLng(stop.latitude, stop.longitude),
                        radius: 50,
                        useRadiusInMeter: true,
                        color: kLogisticsGpsWarning.withValues(alpha: .15),
                        borderColor: kLogisticsGpsWarning,
                        borderStrokeWidth: 1,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(stop.latitude, stop.longitude),
                        width: 44,
                        height: 44,
                        child: const Icon(
                          Icons.location_on,
                          size: 42,
                          color: kLogisticsGpsWarning,
                        ),
                      ),
                    ],
                  ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        'OpenStreetMap contributors',
                        onTap: () => launchUrl(
                          Uri.parse('https://www.openstreetmap.org/copyright'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

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

class _StopReviewDialog extends StatefulWidget {
  final LogisticsGpsStop stop;
  const _StopReviewDialog({required this.stop});
  @override
  State<_StopReviewDialog> createState() => _StopReviewDialogState();
}

class _StopReviewDialogState extends State<_StopReviewDialog> {
  late final _note = TextEditingController(text: widget.stop.reviewNote ?? '');
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await LogisticsGpsStopStore.review(widget.stop, _note.text);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is PostgrestException && error.code == '40001'
              ? 'La revisión cambió. Copia tu nota y vuelve a abrir la parada.'
              : 'No se pudo guardar. Tu nota se conserva; puedes reintentar.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Dialog(
      backgroundColor: kLogisticsSilverSurfaceTop,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Revisar parada · ${widget.stop.unitLabel}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(gpsVisitDate(widget.stop.startedAt)),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('stop-review-note'),
                  controller: _note,
                  autofocus: true,
                  enabled: !_saving,
                  maxLength: 1000,
                  minLines: 2,
                  maxLines: 4,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Motivo o nota de revisión',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escribe el motivo o una nota de revisión.'
                      : null,
                  onFieldSubmitted: (_) => _save(),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: kLogisticsGpsWarning),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Guardando…' : 'Guardar revisión'),
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
