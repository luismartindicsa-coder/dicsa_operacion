import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../services/services_shell.dart';
import '../services/services_visual_mode.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import 'logistics_area_chrome.dart';
import 'logistics_gps_store.dart';
import 'logistics_geofence_store.dart';
import 'logistics_geofence_widgets.dart';
import 'logistics_gps_visits_panel.dart';
import 'logistics_gps_reconciliation_panel.dart';
import 'logistics_gps_trash_widgets.dart';
import 'logistics_gps_stops_panel.dart';
import 'logistics_navigation.dart';
import 'logistics_operations_pages.dart' show logisticsWorkspaceTheme;
import 'logistics_theme.dart';

// Workflow Master-Detail: same shell, navigation and list interaction as Estado de
// Unidades; map surface, tiles and attribution cloned from Catálogos Operativos.
class LogisticsGpsPage extends StatefulWidget {
  const LogisticsGpsPage({super.key});
  @override
  State<LogisticsGpsPage> createState() => _LogisticsGpsPageState();
}

class _LogisticsGpsPageState extends State<LogisticsGpsPage>
    with WidgetsBindingObserver {
  final _map = MapController();
  final _search = TextEditingController();
  final _fenceSearch = TextEditingController();
  final _fenceScroll = ScrollController();
  final _fenceFocus = FocusNode();
  int _mode = 0;
  bool get _geofenceMode => _mode == 1;
  String? _selectedFenceKey;
  String _fenceFilter = 'Todas';
  Timer? _refresh;
  LogisticsGpsBundle? _bundle;
  String? _selectedId, _error;
  String _filter = 'Todas';
  bool _reloadQueued = false;
  bool _loading = false,
      _denied = false,
      _mapReady = false,
      _canDirection = false,
      _active = true;
  DateTime _now = DateTime.now().toUtc();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
    unawaited(_resolveAccess());
    _refresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_active) unawaited(_load());
    });
  }

  Future<void> _resolveAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (mounted) {
      setState(() => _canDirection = AuthAccess.isDirectionRole(profile));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Desktop windows can remain visible while another app has keyboard focus.
    _active =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (_active) unawaited(_load());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _map.dispose();
    _search.dispose();
    _fenceSearch.dispose();
    _fenceScroll.dispose();
    _fenceFocus.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) {
      _reloadQueued = true;
      return;
    }
    _loading = true;
    try {
      final bundle = await LogisticsGpsStore.load();
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _error = null;
        _denied = false;
        _now = DateTime.now().toUtc();
      });
    } catch (error) {
      if (!mounted) return;
      final denied =
          error is LogisticsGpsAccessDenied ||
          (error is PostgrestException &&
              [
                '42501',
                'PGRST301',
                'PGRST302',
                'PGRST303',
              ].contains(error.code));
      setState(() {
        _now = DateTime.now().toUtc();
        _denied = denied;
        if (denied) {
          _bundle = null;
          _mapReady = false;
        }
        _error = denied
            ? 'Tu cuenta no tiene acceso a las ubicaciones de Logística.'
            : 'No se pudo consultar la actualización de GPS. Se reintentará automáticamente.';
      });
    } finally {
      _loading = false;
      if (_reloadQueued && mounted) {
        _reloadQueued = false;
        unawaited(_load());
      }
    }
  }

  List<LogisticsGpsUnit> get _visibleUnits =>
      (_bundle?.units ?? <LogisticsGpsUnit>[]).where((unit) {
        final query = _search.text.trim().toUpperCase();
        if (!'${unit.label} ${unit.providerName}'.toUpperCase().contains(
          query,
        )) {
          return false;
        }
        final status = unit.status(_now);
        return switch (_filter) {
          'Recientes' => status == LogisticsGpsPositionStatus.recent,
          'Atrasadas' => status == LogisticsGpsPositionStatus.delayed,
          'Sin posición' => !unit.hasPosition,
          _ => true,
        };
      }).toList();

  LogisticsGpsUnit? get _selected {
    final units = _visibleUnits;
    return units.where((u) => u.providerId == _selectedId).firstOrNull ??
        units.firstOrNull;
  }

  void _select(LogisticsGpsUnit unit) {
    setState(() => _selectedId = unit.providerId);
    if (_mapReady && unit.hasPosition) {
      _map.move(LatLng(unit.latitude!, unit.longitude!), 14);
    }
  }

  void _fitMap() {
    if (!_mapReady) return;
    if (_geofenceMode) {
      _fitFences(_visibleFences);
      return;
    }
    final points = _visibleUnits
        .where((u) => u.hasPosition)
        .map((u) => LatLng(u.latitude!, u.longitude!))
        .toList();
    if (points.isEmpty) return;
    if (points.length == 1) {
      _map.move(points.single, 14);
      return;
    }
    _map.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(64),
        maxZoom: 15,
      ),
    );
  }

  List<LogisticsGeofence> get _visibleFences =>
      (_bundle?.geofences.fences ?? <LogisticsGeofence>[]).where((f) {
        final query = _fenceSearch.text.trim().toUpperCase();
        if (!'${f.name} ${f.siteName ?? ''}'.toUpperCase().contains(query)) {
          return false;
        }
        return switch (_fenceFilter) {
          'Pendientes' => f.needsReview,
          'Empresas' => f.classification == 'company',
          'Bases' => f.classification == 'base',
          'No disponibles' => !f.visible,
          _ => true,
        };
      }).toList();

  LogisticsGeofence? get _selectedFence =>
      _visibleFences.where((f) => f.key == _selectedFenceKey).firstOrNull ??
      _visibleFences.firstOrNull;

  void _fitFences(Iterable<LogisticsGeofence> fences) {
    if (!_mapReady) return;
    final points = fences
        .where((f) => f.hasGeometry)
        .expand((f) => f.fitPoints)
        .toList();
    if (points.isEmpty) return;
    _map.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(64),
        maxZoom: 18,
      ),
    );
  }

  void _selectFence(LogisticsGeofence fence) {
    setState(() => _selectedFenceKey = fence.key);
    _fitFences([fence]);
  }

  Future<void> _editFence(LogisticsGeofence fence) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => Theme(
        data: logisticsWorkspaceTheme(Theme.of(context)),
        child: LogisticsGeofenceLinkDialog(fence: fence),
      ),
    );
    if (saved == true && mounted) await _load();
  }

  Widget _fenceList() {
    final fences = _visibleFences;
    if (fences.isEmpty) {
      return const Center(child: Text('No hay geocercas con estos filtros.'));
    }
    return Focus(
      focusNode: _fenceFocus,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent ||
            ![
              LogicalKeyboardKey.arrowDown,
              LogicalKeyboardKey.arrowUp,
            ].contains(event.logicalKey)) {
          return KeyEventResult.ignored;
        }
        final current = fences.indexWhere((f) => f.key == _selectedFence?.key);
        final next =
            (current +
                    (event.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1))
                .clamp(0, fences.length - 1);
        _selectFence(fences[next]);
        if (_fenceScroll.hasClients) {
          _fenceScroll.animateTo(
            (next * 96.0).clamp(0, _fenceScroll.position.maxScrollExtent),
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
          );
        }
        return KeyEventResult.handled;
      },
      child: ListView.builder(
        controller: _fenceScroll,
        key: const PageStorageKey('gps-fences'),
        itemExtent: 96,
        itemCount: fences.length,
        itemBuilder: (context, index) {
          final f = fences[index], selected = f.key == _selectedFence?.key;
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
              key: ValueKey('geofence-${f.key}'),
              onTap: () {
                _fenceFocus.requestFocus();
                _selectFence(f);
              },
              leading: Icon(
                f.visible ? Icons.fence_outlined : Icons.location_off_outlined,
                color: f.needsReview
                    ? kLogisticsGpsWarning
                    : kLogisticsSilverIcon,
              ),
              title: Text(
                f.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${f.linkLabel}\n${f.visible ? f.shapeLabel : 'No disponible en EPCOM'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _mainList() => _geofenceMode ? _fenceList() : _unitList();

  void _navigate(String label) {
    if (label == kLogisticsNavGpsLabel ||
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

  String _date(DateTime? date) {
    if (date == null) return 'Sin registro';
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  String _statusLabel(LogisticsGpsUnit unit) => switch (unit.status(_now)) {
    LogisticsGpsPositionStatus.recent => 'Posición reciente',
    LogisticsGpsPositionStatus.delayed => 'Posición atrasada',
    LogisticsGpsPositionStatus.missing => 'Sin posición disponible',
    LogisticsGpsPositionStatus.unavailable => 'Unidad no disponible en EPCOM',
    LogisticsGpsPositionStatus.future => 'Revisar hora del GPS',
  };
  Color _statusColor(LogisticsGpsUnit unit) =>
      unit.status(_now) == LogisticsGpsPositionStatus.recent
      ? kLogisticsGpsRecent
      : kLogisticsGpsWarning;

  String _placeLabel(LogisticsGpsUnit unit) => _bundle!.visits.location(
    unit.providerId,
    _now,
    sourceFresh:
        unit.hasPosition &&
        !unit.positionAt!.isAfter(_now) &&
        _now.difference(unit.positionAt!) <= const Duration(minutes: 15) &&
        _bundle!.connectionNotice(_now) == null &&
        _bundle!.geofences.notice(_now) == null,
  );

  @override
  Widget build(BuildContext context) => ServicesVisualModeScope(
    logisticsSilverMode: true,
    child: AreaThemeScope(
      tokens: logisticsAreaTokens,
      child: Theme(
        data: logisticsWorkspaceTheme(Theme.of(context)),
        child: ServicesShell(
          headerTitle: kLogisticsNavGpsLabel,
          servicesNavLabel: kLogisticsNavGpsLabel,
          sideMenuWidth: kLogisticsSideMenuWidth,
          customSideMenuBuilder: (context, close) => LogisticsAreaSidePanel(
            currentLabel: kLogisticsNavGpsLabel,
            canReturnToDirection: _canDirection,
            onNavigate: (label) {
              close();
              _navigate(label);
            },
          ),
          onLogout: () => signOutAndRouteToLogin(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_error != null) _notice(_error!),
                if (_bundle?.connectionNotice(_now) case final notice?)
                  _notice(notice),
                if (_bundle?.geofences.notice(_now) case final notice?)
                  _notice(notice),
                if (_bundle?.visits.notice(_now) case final notice?)
                  _notice(notice),
                if (_mode == 3)
                  if (_bundle?.stops.notice(_now) case final notice?)
                    _notice(notice),
                if (_bundle?.tokenExpiresAt case final expiry?)
                  if (expiry.difference(_now) <= const Duration(days: 7))
                    _notice(
                      'El acceso a EPCOM vence el ${_date(expiry)}. Solicita su renovación.',
                    ),
                if (_bundle == null)
                  Expanded(
                    child: Center(
                      child: _error == null && !_denied
                          ? const CircularProgressIndicator()
                          : const Text('Ubicaciones no disponibles.'),
                    ),
                  )
                else ...[
                  _toolbar(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: IndexedStack(
                      index: _mode >= 2 ? _mode - 1 : 0,
                      children: [
                        LayoutBuilder(
                          builder: (context, size) {
                            if (size.maxWidth < 850) {
                              return Column(
                                children: [
                                  SizedBox(
                                    height: size.maxHeight * .38,
                                    child: _mainList(),
                                  ),
                                  const SizedBox(height: 10),
                                  Expanded(child: _mapPanel()),
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(width: 320, child: _mainList()),
                                const SizedBox(width: 14),
                                Expanded(child: _mapPanel()),
                              ],
                            );
                          },
                        ),
                        LogisticsGpsVisitsPanel(
                          curation: _bundle!.curation,
                          onChanged: _load,
                          bundle: _bundle!.visits,
                          now: _now,
                          sourceFresh:
                              _bundle!.connectionNotice(_now) == null &&
                              _bundle!.geofences.notice(_now) == null,
                        ),
                        LogisticsGpsStopsPanel(
                          curation: _bundle!.curation,
                          bundle: _bundle!.stops,
                          now: _now,
                          geofences: _bundle!.geofences.fences,
                          onChanged: _load,
                          sourceFresh:
                              _bundle!.connectionNotice(_now) == null &&
                              _bundle!.geofences.notice(_now) == null,
                        ),
                        LogisticsGpsReconciliationPanel(
                          curation: _bundle!.curation,
                          onChanged: _load,
                          bundle: _bundle!.visits,
                          now: _now,
                          active: _mode == 4,
                          sourceFresh:
                              _error == null &&
                              _bundle!.connectionNotice(_now) == null &&
                              _bundle!.geofences.notice(_now) == null,
                        ),
                        LogisticsGpsTrashPanel(
                          curation: _bundle!.curation,
                          onChanged: _load,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _notice(String text) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: kLogisticsSilverSurfaceElevated,
      border: Border.all(color: kLogisticsGpsWarning),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, color: kLogisticsGpsWarning, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );

  Widget _toolbar() => Wrap(
    spacing: 12,
    runSpacing: 10,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              label: Text('Unidades'),
              icon: Icon(Icons.local_shipping_outlined),
            ),
            ButtonSegment(
              value: 1,
              label: Text('Geocercas'),
              icon: Icon(Icons.fence_outlined),
            ),
            ButtonSegment(
              value: 2,
              label: Text('Visitas'),
              icon: Icon(Icons.history),
            ),
            ButtonSegment(
              value: 3,
              label: Text('Paradas'),
              icon: Icon(Icons.pause_circle_outline),
            ),
            ButtonSegment(
              value: 4,
              label: Text('Asignación'),
              icon: Icon(Icons.fact_check_outlined),
            ),
            ButtonSegment(
              value: 5,
              label: Text('Papelera'),
              icon: Icon(Icons.delete_outline),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (selection) {
            setState(() => _mode = selection.single);
            if (_mode >= 2) return;
            if (_geofenceMode && _selectedFence != null) {
              _fitFences([_selectedFence!]);
            } else {
              _fitMap();
            }
          },
        ),
      ),
      if (_mode < 2) ...[
        SizedBox(
          width: 280,
          child: TextField(
            key: ValueKey(_geofenceMode ? 'geofence-search' : 'gps-search'),
            controller: _geofenceMode ? _fenceSearch : _search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: _geofenceMode
                  ? 'Buscar geocerca o empresa'
                  : 'Buscar unidad',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<String>(
            key: ValueKey(_geofenceMode),
            initialValue: _geofenceMode ? _fenceFilter : _filter,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Mostrar'),
            items:
                (_geofenceMode
                        ? [
                            'Todas',
                            'Pendientes',
                            'Empresas',
                            'Bases',
                            'No disponibles',
                          ]
                        : ['Todas', 'Recientes', 'Atrasadas', 'Sin posición'])
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  if (_geofenceMode) {
                    _fenceFilter = value;
                  } else {
                    _filter = value;
                  }
                });
              }
            },
          ),
        ),
        Text(
          _geofenceMode
              ? '${_bundle!.geofences.fences.length} geocercas · ${_bundle!.geofences.fences.where((f) => f.needsReview).length} pendientes'
              : '${_bundle!.units.length} unidades · ${_bundle!.units.where((u) => u.status(_now) == LogisticsGpsPositionStatus.recent).length} recientes',
        ),
        Text(
          'Consulta EPCOM: ${_date(_geofenceMode ? _bundle!.geofences.lastSuccessAt : _bundle!.lastSuccessAt)}',
          style: const TextStyle(
            color: kLogisticsSilverTextSecondary,
            fontSize: 12,
          ),
        ),
      ],
    ],
  );

  Widget _unitList() {
    final units = _visibleUnits;
    if (units.isEmpty) {
      return const Center(child: Text('No hay unidades con estos filtros.'));
    }
    return ListView.separated(
      key: const PageStorageKey('gps-units'),
      itemCount: units.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final unit = units[index];
        final selected = unit.providerId == _selected?.providerId;
        return Card(
          clipBehavior: Clip.antiAlias,
          color: selected
              ? kLogisticsSilverSurfaceInteractive
              : kLogisticsSilverSurfaceTop,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: selected
                  ? logisticsAreaTokens.primaryStrong
                  : logisticsAreaTokens.border,
            ),
          ),
          child: ListTile(
            key: ValueKey('gps-unit-${unit.providerId}'),
            selected: selected,
            selectedColor: kLogisticsSilverTextPrimary,
            onTap: () => _select(unit),
            leading: Icon(
              unit.hasPosition
                  ? Icons.local_shipping_outlined
                  : Icons.location_off_outlined,
              color: _statusColor(unit),
            ),
            title: Text(
              unit.label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusLabel(unit),
                  style: TextStyle(color: _statusColor(unit)),
                ),
                Text(
                  _date(unit.positionAt),
                  style: const TextStyle(fontSize: 11),
                ),
                if (unit.vehicleId != null)
                  Text(_placeLabel(unit), style: const TextStyle(fontSize: 12)),
                if (unit.vehicleId == null)
                  const Text(
                    'Sin vínculo en el catálogo',
                    style: TextStyle(color: kLogisticsGpsWarning),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _mapPanel() {
    final selected = _selected;
    final fence = _geofenceMode ? _selectedFence : null;
    final units = _visibleUnits.where((u) => u.hasPosition).toList()
      ..sort(
        (a, b) => (a.providerId == selected?.providerId ? 1 : 0).compareTo(
          b.providerId == selected?.providerId ? 1 : 0,
        ),
      );
    final points = units
        .map((unit) => LatLng(unit.latitude!, unit.longitude!))
        .toList();
    return Card(
      clipBehavior: Clip.antiAlias,
      color: kLogisticsSilverSurfaceTop,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: kLogisticsSilverBorder),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _geofenceMode
                            ? (fence == null
                                  ? 'Geocercas de EPCOM'
                                  : '${fence.name} · ${fence.linkLabel}')
                            : selected == null
                            ? 'Ubicación de unidades'
                            : '${selected.label} · ${_statusLabel(selected)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (_geofenceMode && fence != null)
                        Text(
                          fence.visible
                              ? fence.shapeLabel
                              : 'No disponible en EPCOM',
                          style: const TextStyle(
                            fontSize: 12,
                            color: kLogisticsSilverTextSecondary,
                          ),
                        ),
                      if (!_geofenceMode && selected != null)
                        Text(
                          'Última posición: ${_date(selected.positionAt)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: kLogisticsSilverTextSecondary,
                          ),
                        ),
                      if (!_geofenceMode &&
                          selected != null &&
                          selected.vehicleId != null)
                        Text(
                          _placeLabel(selected),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_geofenceMode && fence != null)
                  OutlinedButton.icon(
                    onPressed: fence.visible ? () => _editFence(fence) : null,
                    icon: const Icon(Icons.link),
                    label: const Text('Vincular'),
                  ),
                IconButton(
                  tooltip: _geofenceMode
                      ? 'Ver todas las geocercas'
                      : 'Ver todas las ubicaciones',
                  onPressed:
                      (_geofenceMode ? _visibleFences.isEmpty : units.isEmpty)
                      ? null
                      : _fitMap,
                  icon: const Icon(Icons.fit_screen),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter:
                        points.firstOrNull ?? const LatLng(20.5235, -100.8157),
                    initialZoom: points.length == 1 ? 14 : 10.9,
                    initialCameraFit: points.length > 1
                        ? CameraFit.bounds(
                            bounds: LatLngBounds.fromPoints(points),
                            padding: const EdgeInsets.all(64),
                            maxZoom: 15,
                          )
                        : null,
                    onMapReady: () {
                      _mapReady = true;
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.dicsa.operacion',
                    ),
                    LogisticsGeofenceLayer(
                      fences: _geofenceMode
                          ? _visibleFences
                          : _bundle!.geofences.fences,
                      selectedKey: fence?.key,
                    ),
                    MarkerLayer(
                      markers: units
                          .map(
                            (unit) => Marker(
                              width: 90,
                              height: 64,
                              point: LatLng(unit.latitude!, unit.longitude!),
                              child: Tooltip(
                                message:
                                    '${unit.label} · ${_statusLabel(unit)}',
                                child: GestureDetector(
                                  onTap: () => _select(unit),
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              unit.providerId ==
                                                  selected?.providerId
                                              ? kLogisticsSilverTextPrimary
                                              : kLogisticsSilverSurfaceTop,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: logisticsAreaTokens.border,
                                          ),
                                        ),
                                        child: Text(
                                          unit.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color:
                                                unit.providerId ==
                                                    selected?.providerId
                                                ? kLogisticsSilverSurfaceTop
                                                : kLogisticsSilverTextPrimary,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.location_on,
                                        size: 34,
                                        color: _statusColor(unit),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                          'OpenStreetMap contributors',
                          onTap: () => unawaited(
                            launchUrl(
                              Uri.parse(
                                'https://www.openstreetmap.org/copyright',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (!_geofenceMode && units.isEmpty)
                  Center(
                    child: _notice(
                      'No hay posiciones disponibles para estas unidades.',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
