import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/general_dashboard_page.dart';
import '../services/services_shell.dart';
import '../services/services_visual_mode.dart';
import '../shared/app_ui/app_ui_widgets.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import 'logistics_area_chrome.dart';
import 'logistics_company_profile_store.dart';
import 'logistics_control_daily_page.dart';
import 'logistics_dashboard_page.dart';
import 'logistics_diesel_page.dart';
import 'logistics_geocoding_service.dart';
import 'logistics_theme.dart';
import 'logistics_zone_store.dart';

const String _kZonePolygonTemplateNone = 'NONE';
const String _kZonePolygonTemplateExisting = 'EXISTING';

class _ZonePolygonTemplate {
  final String key;
  final String code;
  final String label;
  final List<LatLng> points;

  const _ZonePolygonTemplate({
    required this.key,
    required this.code,
    required this.label,
    required this.points,
  });
}

class _RenderedZonePolygon {
  final String code;
  final String label;
  final Color fillColor;
  final Color borderColor;
  final List<LatLng> points;
  final bool fallbackTemplate;

  const _RenderedZonePolygon({
    required this.code,
    required this.label,
    required this.fillColor,
    required this.borderColor,
    required this.points,
    required this.fallbackTemplate,
  });
}

List<_ZonePolygonTemplate> _logisticsZonePolygonTemplates() {
  return const <_ZonePolygonTemplate>[
    _ZonePolygonTemplate(
      key: 'CEL_NO',
      code: 'NO',
      label: 'Noroeste',
      points: <LatLng>[
        LatLng(20.6900, -101.0200),
        LatLng(20.6900, -100.8120),
        LatLng(20.5220, -100.8120),
        LatLng(20.5220, -101.0200),
      ],
    ),
    _ZonePolygonTemplate(
      key: 'CEL_NE',
      code: 'NE',
      label: 'Noreste',
      points: <LatLng>[
        LatLng(20.6900, -100.8120),
        LatLng(20.6900, -100.6000),
        LatLng(20.5220, -100.6000),
        LatLng(20.5220, -100.8120),
      ],
    ),
    _ZonePolygonTemplate(
      key: 'CEL_SO',
      code: 'SO',
      label: 'Suroeste',
      points: <LatLng>[
        LatLng(20.5220, -101.0200),
        LatLng(20.5220, -100.8120),
        LatLng(20.3500, -100.8120),
        LatLng(20.3500, -101.0200),
      ],
    ),
    _ZonePolygonTemplate(
      key: 'CEL_SE',
      code: 'SE',
      label: 'Sureste',
      points: <LatLng>[
        LatLng(20.5220, -100.8120),
        LatLng(20.5220, -100.6000),
        LatLng(20.3500, -100.6000),
        LatLng(20.3500, -100.8120),
      ],
    ),
  ];
}

_ZonePolygonTemplate? _zonePolygonTemplateByKey(String key) {
  for (final template in _logisticsZonePolygonTemplates()) {
    if (template.key == key) return template;
  }
  return null;
}

double? _zonePolygonDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

List<LatLng> _zonePolygonPointsFromRaw(List<dynamic> raw) {
  final points = <LatLng>[];
  for (final item in raw) {
    if (item is Map) {
      final row = Map<String, dynamic>.from(item);
      final lat = _zonePolygonDouble(row['lat'] ?? row['latitude']);
      final lng = _zonePolygonDouble(
        row['lng'] ?? row['lon'] ?? row['longitude'],
      );
      if (lat != null && lng != null) {
        points.add(LatLng(lat, lng));
      }
      continue;
    }
    if (item is List && item.length >= 2) {
      final lat = _zonePolygonDouble(item[0]);
      final lng = _zonePolygonDouble(item[1]);
      if (lat != null && lng != null) {
        points.add(LatLng(lat, lng));
      }
    }
  }
  return points.length >= 3 ? points : const <LatLng>[];
}

List<Map<String, double>> _zonePolygonPointsToJson(List<LatLng> points) {
  return points
      .map(
        (point) => <String, double>{
          'lat': point.latitude,
          'lng': point.longitude,
        },
      )
      .toList(growable: false);
}

bool _sameZonePolygon(List<LatLng> a, List<LatLng> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final sameLat = (a[i].latitude - b[i].latitude).abs() < 0.000001;
    final sameLng = (a[i].longitude - b[i].longitude).abs() < 0.000001;
    if (!sameLat || !sameLng) return false;
  }
  return true;
}

String _inferZonePolygonTemplateKey(
  LogisticsZoneRecord? zone, {
  int fallbackIndex = -1,
}) {
  if (zone != null) {
    final explicit = _zonePolygonPointsFromRaw(zone.polygonPoints);
    if (explicit.isNotEmpty) {
      for (final template in _logisticsZonePolygonTemplates()) {
        if (_sameZonePolygon(explicit, template.points)) {
          return template.key;
        }
      }
      return _kZonePolygonTemplateExisting;
    }

    final probe = '${zone.code} ${zone.name}'.toUpperCase();
    if (probe.contains('NOROESTE') ||
        probe.contains('NORTE PONIENTE') ||
        RegExp(r'(^|[^A-Z])NO([^A-Z]|$)').hasMatch(probe)) {
      return 'CEL_NO';
    }
    if (probe.contains('NORESTE') ||
        probe.contains('NORTE ORIENTE') ||
        RegExp(r'(^|[^A-Z])NE([^A-Z]|$)').hasMatch(probe)) {
      return 'CEL_NE';
    }
    if (probe.contains('SUROESTE') ||
        probe.contains('SUR PONIENTE') ||
        RegExp(r'(^|[^A-Z])SO([^A-Z]|$)').hasMatch(probe)) {
      return 'CEL_SO';
    }
    if (probe.contains('SURESTE') ||
        probe.contains('SUR ORIENTE') ||
        RegExp(r'(^|[^A-Z])SE([^A-Z]|$)').hasMatch(probe)) {
      return 'CEL_SE';
    }
  }

  if (fallbackIndex >= 0 &&
      fallbackIndex < _logisticsZonePolygonTemplates().length) {
    return _logisticsZonePolygonTemplates()[fallbackIndex].key;
  }

  return _kZonePolygonTemplateNone;
}

List<LatLng> _resolvedZonePolygonPointsForRecord(
  LogisticsZoneRecord zone, {
  required int fallbackIndex,
}) {
  final explicit = _zonePolygonPointsFromRaw(zone.polygonPoints);
  if (explicit.length >= 3) return explicit;
  final templateKey = _inferZonePolygonTemplateKey(
    zone,
    fallbackIndex: fallbackIndex,
  );
  final template = _zonePolygonTemplateByKey(templateKey);
  return template?.points ?? const <LatLng>[];
}

bool _isPointOnPolygonSegment(
  LatLng point,
  LatLng start,
  LatLng end, {
  double tolerance = 0.000001,
}) {
  final dx = end.longitude - start.longitude;
  final dy = end.latitude - start.latitude;
  final cross =
      (point.longitude - start.longitude) * dy -
      (point.latitude - start.latitude) * dx;
  if (cross.abs() > tolerance) return false;

  final dot =
      (point.longitude - start.longitude) * dx +
      (point.latitude - start.latitude) * dy;
  if (dot < -tolerance) return false;

  final squaredLength = dx * dx + dy * dy;
  if (dot - squaredLength > tolerance) return false;
  return true;
}

bool _isPointInsidePolygon(LatLng point, List<LatLng> polygon) {
  if (polygon.length < 3) return false;

  for (var i = 0; i < polygon.length; i++) {
    final start = polygon[i];
    final end = polygon[(i + 1) % polygon.length];
    if (_isPointOnPolygonSegment(point, start, end)) {
      return true;
    }
  }

  var inside = false;
  final x = point.longitude;
  final y = point.latitude;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final xi = polygon[i].longitude;
    final yi = polygon[i].latitude;
    final xj = polygon[j].longitude;
    final yj = polygon[j].latitude;

    final intersects =
        ((yi > y) != (yj > y)) &&
        (x <
            (xj - xi) * (y - yi) / ((yj - yi) == 0 ? 0.0000000001 : (yj - yi)) +
                xi);
    if (intersects) inside = !inside;
  }
  return inside;
}

class _ZoneDetectionResult {
  final LatLng point;
  final List<LogisticsZoneRecord> matches;

  const _ZoneDetectionResult({required this.point, required this.matches});

  LogisticsZoneRecord? get singleMatch =>
      matches.length == 1 ? matches.first : null;
  bool get hasSingleMatch => singleMatch != null;
  bool get hasMultipleMatches => matches.length > 1;
  bool get hasAnyMatch => matches.isNotEmpty;
}

enum _CompanyLocationStatusKind {
  located,
  pendingLocation,
  pendingZone,
  outsidePolygon,
  reviewZone,
}

class _CompanyLocationStatus {
  final _CompanyLocationStatusKind kind;
  final String label;
  final String detail;
  final IconData icon;
  final Color foreground;
  final Color background;
  final Color border;

  const _CompanyLocationStatus({
    required this.kind,
    required this.label,
    required this.detail,
    required this.icon,
    required this.foreground,
    required this.background,
    required this.border,
  });

  bool get isPending =>
      kind == _CompanyLocationStatusKind.pendingLocation ||
      kind == _CompanyLocationStatusKind.pendingZone;
}

class _CompanyCatalogStatusRow {
  final LogisticsCompanyProfileRecord row;
  final _CompanyLocationStatus status;

  const _CompanyCatalogStatusRow({required this.row, required this.status});
}

_ZoneDetectionResult _detectZoneForCoordinate({
  required LatLng point,
  required List<LogisticsZoneRecord> zones,
}) {
  final matches = <LogisticsZoneRecord>[];
  for (var i = 0; i < zones.length; i++) {
    final polygon = _resolvedZonePolygonPointsForRecord(
      zones[i],
      fallbackIndex: i,
    );
    if (polygon.length >= 3 && _isPointInsidePolygon(point, polygon)) {
      matches.add(zones[i]);
    }
  }
  return _ZoneDetectionResult(point: point, matches: matches);
}

Color _zoneColorFromHex(String value) {
  final normalized = normalizeLogisticsZoneColorHex(value);
  return Color(int.parse(normalized.substring(1), radix: 16) + 0xFF000000);
}

class LogisticsCatalogPage extends StatefulWidget {
  const LogisticsCatalogPage({super.key});

  @override
  State<LogisticsCatalogPage> createState() => _LogisticsCatalogPageState();
}

class _LogisticsCatalogPageState extends State<LogisticsCatalogPage> {
  final SupabaseClient _supa = Supabase.instance.client;
  final ScrollController _zonesScrollController = ScrollController();
  final ScrollController _containersScrollController = ScrollController();

  bool _loading = true;
  bool _canReturnToDirection = false;
  String? _loadError;

  List<LogisticsCompanyProfileRecord> _companyProfiles = const [];
  List<LogisticsZoneRecord> _zones = const [];
  List<Map<String, dynamic>> _drivers = const [];
  List<Map<String, dynamic>> _vehicles = const [];

  String _companySearch = '';
  String _zoneSearch = '';
  String _driverSearch = '';
  String _vehicleSearch = '';

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _zonesScrollController.dispose();
    _containersScrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final results = await Future.wait<dynamic>([
        AuthAccess.resolveCurrentProfile(),
        LogisticsCompanyProfileStore.loadProfiles(),
        LogisticsZoneStore.loadZones(),
        _supa
            .from('employees')
            .select('id,full_name,is_active')
            .eq('is_driver', true)
            .eq('is_active', true)
            .order('full_name'),
        _supa
            .from('vehicles')
            .select('id,code,serial_number,status,type')
            .eq('status', 'activo')
            .order('code'),
      ]);
      if (!mounted) return;

      setState(() {
        _canReturnToDirection = AuthAccess.isDirectionRole(
          results[0] as AuthResolvedProfile?,
        );
        _companyProfiles = (results[1] as List)
            .cast<LogisticsCompanyProfileRecord>();
        _zones = (results[2] as List).cast<LogisticsZoneRecord>();
        _drivers = (results[3] as List).cast<Map<String, dynamic>>();
        _vehicles = (results[4] as List).cast<Map<String, dynamic>>();
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'No se pudieron cargar los catálogos: $error';
      });
    }
  }

  Future<void> _openLogisticsDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const LogisticsDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _openControlDaily() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const LogisticsControlDailyPage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _openDirectionDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const GeneralDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _openDiesel() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const LogisticsDieselPage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  void _showPhaseSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _handleNavigationAction(String label) {
    switch (label) {
      case kLogisticsNavDashboardLabel:
        unawaited(_openLogisticsDashboard());
        return;
      case kLogisticsNavControlDailyLabel:
        unawaited(_openControlDaily());
        return;
      case kLogisticsNavCatalogsLabel:
        return;
      case kLogisticsNavDieselLabel:
        unawaited(_openDiesel());
        return;
      case kLogisticsNavFleetStatusLabel:
        _showPhaseSnack(
          'Estado de Unidades se conectará después de homologar esta lectura de catálogos.',
        );
        return;
      case kLogisticsNavIncidentsLabel:
        _showPhaseSnack(
          'Incidencias se habilitará cuando el tablero operativo ya lea estas bases maestras.',
        );
        return;
      case kLogisticsNavSavingsLabel:
        _showPhaseSnack(
          'Ahorro y Planeación nacerá encima de empresas, zonas y contenedores.',
        );
        return;
      case kLogisticsNavDirectionDashboardLabel:
        unawaited(_openDirectionDashboard());
        return;
    }
  }

  String _normalizeSearch(String value) {
    return value.trim().toLowerCase();
  }

  bool _matchesSearch(String query, Iterable<String> values) {
    final normalized = _normalizeSearch(query);
    if (normalized.isEmpty) return true;
    for (final entry in values) {
      final value = entry.toLowerCase();
      if (value.contains(normalized)) return true;
    }
    return false;
  }

  List<LogisticsCompanyProfileRecord> get _filteredCompanies {
    return _companyProfiles
        .where(
          (row) => _matchesSearch(_companySearch, [
            row.siteName,
            row.operationalContact,
            row.contactPhone,
            row.addressLine,
            row.pickupWindow,
          ]),
        )
        .toList(growable: false);
  }

  List<LogisticsZoneRecord> get _filteredZones {
    return _zones
        .where((row) => row.active)
        .where(
          (row) => _matchesSearch(_zoneSearch, [
            row.code,
            row.name,
            row.city,
            row.state,
            row.coverageHint,
            row.notes,
          ]),
        )
        .toList(growable: false);
  }

  List<Map<String, dynamic>> get _filteredDrivers {
    return _drivers
        .where(
          (row) => _matchesSearch(_driverSearch, [
            (row['full_name'] ?? '').toString(),
            (row['id'] ?? '').toString(),
          ]),
        )
        .toList(growable: false);
  }

  List<Map<String, dynamic>> get _filteredVehicles {
    return _vehicles
        .where(
          (row) => _matchesSearch(_vehicleSearch, [
            (row['code'] ?? '').toString(),
            (row['serial_number'] ?? '').toString(),
            (row['type'] ?? '').toString(),
            (row['status'] ?? '').toString(),
          ]),
        )
        .toList(growable: false);
  }

  String _prettyLabel(String value) {
    final clean = value.trim().replaceAll('_', ' ');
    if (clean.isEmpty) return 'Pendiente';
    return clean
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) {
          final lower = part.toLowerCase();
          return lower[0].toUpperCase() + lower.substring(1);
        })
        .join(' ');
  }

  Map<String, LogisticsZoneRecord> get _zoneById {
    return <String, LogisticsZoneRecord>{
      for (final zone in _zones) zone.id: zone,
    };
  }

  List<LogisticsZoneRecord> get _activeZones {
    return _zones.where((zone) => zone.active).toList(growable: false);
  }

  int get _companiesWithContainersCount {
    return _companyProfiles.where((row) => row.hasContainers).length;
  }

  int get _companiesWithAddressCount {
    return _companyProfiles
        .where((row) => row.addressLine.trim().isNotEmpty)
        .length;
  }

  int get _companiesAssignedToZoneCount {
    return _companyProfiles
        .where((row) => (row.zoneId ?? '').trim().isNotEmpty)
        .length;
  }

  int get _companiesReadyForRoutingCount {
    return _companyProfiles
        .where(
          (row) =>
              row.addressLine.trim().isNotEmpty &&
              (row.zoneId ?? '').trim().isNotEmpty,
        )
        .length;
  }

  int get _companiesPendingZoneCaptureCount {
    return _companyProfiles
        .where(
          (row) =>
              row.addressLine.trim().isEmpty ||
              (row.zoneId ?? '').trim().isEmpty,
        )
        .length;
  }

  List<LogisticsCompanyProfileRecord> get _companiesPendingZoneAssignment {
    return _companyProfiles
        .where(
          (row) =>
              row.addressLine.trim().isNotEmpty &&
              (row.zoneId ?? '').trim().isEmpty,
        )
        .toList(growable: false);
  }

  List<LogisticsCompanyProfileRecord> get _companiesPendingAddressCapture {
    return _companyProfiles
        .where((row) => row.addressLine.trim().isEmpty)
        .toList(growable: false);
  }

  Future<void> _reloadCatalogMasters() async {
    final results = await Future.wait<dynamic>([
      LogisticsCompanyProfileStore.loadProfiles(),
      LogisticsZoneStore.loadZones(),
    ]);
    if (!mounted) return;
    setState(() {
      _companyProfiles = (results[0] as List)
          .cast<LogisticsCompanyProfileRecord>();
      _zones = (results[1] as List).cast<LogisticsZoneRecord>();
    });
  }

  Future<void> _editCompanyProfile(LogisticsCompanyProfileRecord record) async {
    final updated = await showDialog<LogisticsCompanyProfileRecord>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LogisticsCompanyProfileEditorDialog(
        record: record,
        zones: _filteredZones,
      ),
    );
    if (updated == null) return;

    try {
      await LogisticsCompanyProfileStore.saveProfileRow(updated);
      await _reloadCatalogMasters();
      if (!mounted) return;
      _showPhaseSnack('Perfil logístico actualizado para ${updated.siteName}.');
    } on PostgrestException catch (error) {
      if (!mounted) return;
      _showPhaseSnack('No se pudo guardar el perfil: ${error.message}');
    } catch (error) {
      if (!mounted) return;
      _showPhaseSnack('No se pudo guardar el perfil: $error');
    }
  }

  Future<void> _createZone() async {
    final created = await showDialog<LogisticsZoneRecord>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _LogisticsZoneEditorDialog(),
    );
    if (created == null) return;

    try {
      await LogisticsZoneStore.saveZoneRow(created);
      await _reloadCatalogMasters();
      if (!mounted) return;
      _showPhaseSnack('Zona ${created.name} creada en Logística.');
    } on PostgrestException catch (error) {
      if (!mounted) return;
      _showPhaseSnack('No se pudo guardar la zona: ${error.message}');
    } catch (error) {
      if (!mounted) return;
      _showPhaseSnack('No se pudo guardar la zona: $error');
    }
  }

  Future<void> _editZone(LogisticsZoneRecord record) async {
    final updated = await showDialog<LogisticsZoneRecord>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LogisticsZoneEditorDialog(record: record),
    );
    if (updated == null) return;

    try {
      await LogisticsZoneStore.saveZoneRow(updated);
      await _reloadCatalogMasters();
      if (!mounted) return;
      _showPhaseSnack('Zona ${updated.name} actualizada.');
    } on PostgrestException catch (error) {
      if (!mounted) return;
      _showPhaseSnack('No se pudo actualizar la zona: ${error.message}');
    } catch (error) {
      if (!mounted) return;
      _showPhaseSnack('No se pudo actualizar la zona: $error');
    }
  }

  String _companyAddressLabel(LogisticsCompanyProfileRecord row) {
    final address = row.addressLine.trim();
    final reference = row.addressReference.trim();
    if (address.isEmpty && reference.isEmpty) {
      return 'Pendiente de capturar para mapa, zona y ruteo.';
    }
    if (reference.isEmpty) return address;
    if (address.isEmpty) return reference;
    return '$address · Ref. $reference';
  }

  String _companyScheduleLabel(LogisticsCompanyProfileRecord row) {
    final parts = <String>[];
    if (row.pickupWindow.trim().isNotEmpty) {
      parts.add('Ventana ${row.pickupWindow.trim()}');
    }
    parts.add(logisticsScheduleFlexibilityLabel(row.scheduleFlexibility));
    if (row.earlyPickupRequired) {
      parts.add('requiere salida temprana');
    }
    return parts.join(' · ');
  }

  String _companyContainersLabel(LogisticsCompanyProfileRecord row) {
    if (!row.hasContainers) {
      return 'Sin contenedores registrados todavía.';
    }
    final parts = <String>['${row.containerCount} contenedor(es)'];
    if (row.containerCapacityNote.trim().isNotEmpty) {
      parts.add(row.containerCapacityNote.trim());
    }
    return parts.join(' · ');
  }

  String _companyPriorityLabel(LogisticsCompanyProfileRecord row) {
    return '${logisticsCollectionUrgencyLabel(row.collectionUrgency)}'
        ' · ${logisticsVolumePressureLabel(row.volumePressure)}';
  }

  String _companyMapLabel(LogisticsCompanyProfileRecord row) {
    if (row.latitude == null || row.longitude == null) {
      return 'Pendiente de ubicar en mapa.';
    }
    final point = LatLng(row.latitude!, row.longitude!);
    final activeZones = _zones
        .where((zone) => zone.active)
        .toList(growable: false);
    final detection = _detectZoneForCoordinate(
      point: point,
      zones: activeZones,
    );
    final base =
        '${row.latitude!.toStringAsFixed(5)}, ${row.longitude!.toStringAsFixed(5)}';
    if (detection.hasSingleMatch) {
      return '$base · ${detection.singleMatch!.code}';
    }
    if (detection.hasMultipleMatches) {
      return '$base · Coincide con ${detection.matches.length} zonas';
    }
    return '$base · Fuera de zona';
  }

  String _companyZoneLabel(LogisticsCompanyProfileRecord row) {
    final zoneId = (row.zoneId ?? '').trim();
    if (zoneId.isEmpty) {
      return 'Pendiente de asignar en el catálogo de zonas.';
    }
    final zone = _zoneById[zoneId];
    if (zone == null) {
      return 'Zona pendiente de homologar o ya no disponible.';
    }
    final parts = <String>['${zone.code} · ${zone.name}'];
    if (row.zoneNotes.trim().isNotEmpty) {
      parts.add(row.zoneNotes.trim());
    }
    return parts.join(' · ');
  }

  List<String> _companyTags(LogisticsCompanyProfileRecord row) {
    final tags = <String>[
      logisticsCollectionUrgencyLabel(row.collectionUrgency),
      logisticsScheduleFlexibilityLabel(row.scheduleFlexibility),
    ];
    if (row.earlyPickupRequired) {
      tags.add('Temprano');
    }
    if (row.hasContainers) {
      tags.add('Contenedores');
    }
    final zoneId = (row.zoneId ?? '').trim();
    if (zoneId.isNotEmpty && _zoneById.containsKey(zoneId)) {
      tags.add(_zoneById[zoneId]!.code);
    }
    return tags;
  }

  _CompanyLocationStatus _companyLocationStatusForRow(
    LogisticsCompanyProfileRecord row,
  ) {
    const readyForeground = Color(0xFF2F5D4E);
    const readyBackground = Color(0xFFE4F0EB);
    const readyBorder = Color(0xFFC5DACE);

    const pendingForeground = Color(0xFF7A5C1F);
    const pendingBackground = Color(0xFFF7EED8);
    const pendingBorder = Color(0xFFE6D2A4);

    const warningForeground = Color(0xFF7A4E1F);
    const warningBackground = Color(0xFFF4E6DA);
    const warningBorder = Color(0xFFE0C3A8);

    const alertForeground = Color(0xFF8A3F3F);
    const alertBackground = Color(0xFFF5E3E3);
    const alertBorder = Color(0xFFD9B7B7);

    final addressPresent = row.addressLine.trim().isNotEmpty;
    final hasCoordinates = row.latitude != null && row.longitude != null;
    final zoneId = (row.zoneId ?? '').trim();
    final manualZone = zoneId.isEmpty ? null : _zoneById[zoneId];

    if (!hasCoordinates) {
      return _CompanyLocationStatus(
        kind: _CompanyLocationStatusKind.pendingLocation,
        label: 'Pendiente de ubicar',
        detail: addressPresent
            ? 'Tiene direccion, pero falta fijar su punto en el mapa.'
            : 'Falta capturar direccion y coordenadas para poder rutearla.',
        icon: Icons.place_rounded,
        foreground: pendingForeground,
        background: pendingBackground,
        border: pendingBorder,
      );
    }

    final point = LatLng(row.latitude!, row.longitude!);
    final activeZones = _activeZones;
    if (activeZones.isEmpty) {
      return _CompanyLocationStatus(
        kind: _CompanyLocationStatusKind.pendingZone,
        label: 'Pendiente de zona',
        detail: 'Todavia no hay zonas activas para validar este punto.',
        icon: Icons.route_rounded,
        foreground: pendingForeground,
        background: pendingBackground,
        border: pendingBorder,
      );
    }

    final detection = _detectZoneForCoordinate(
      point: point,
      zones: activeZones,
    );
    if (detection.hasMultipleMatches) {
      return _CompanyLocationStatus(
        kind: _CompanyLocationStatusKind.reviewZone,
        label: 'Zona por revisar',
        detail:
            'El punto cae en ${detection.matches.length} zonas activas; conviene ajustar poligonos o confirmar sector.',
        icon: Icons.fact_check_outlined,
        foreground: warningForeground,
        background: warningBackground,
        border: warningBorder,
      );
    }

    if (!detection.hasAnyMatch) {
      return _CompanyLocationStatus(
        kind: _CompanyLocationStatusKind.outsidePolygon,
        label: 'Fuera de poligono',
        detail:
            'Tiene coordenadas, pero el punto no cae dentro de ninguna zona activa.',
        icon: Icons.report_problem_outlined,
        foreground: alertForeground,
        background: alertBackground,
        border: alertBorder,
      );
    }

    final detectedZone = detection.singleMatch!;
    if (manualZone == null) {
      return _CompanyLocationStatus(
        kind: _CompanyLocationStatusKind.pendingZone,
        label: 'Pendiente de zona',
        detail:
            'El mapa ya la coloca en ${detectedZone.code} · ${detectedZone.name}; falta confirmarla en el catalogo.',
        icon: Icons.route_rounded,
        foreground: pendingForeground,
        background: pendingBackground,
        border: pendingBorder,
      );
    }

    if (!manualZone.active) {
      return _CompanyLocationStatus(
        kind: _CompanyLocationStatusKind.reviewZone,
        label: 'Zona por revisar',
        detail:
            'La zona asignada ya no esta activa y necesita homologacion antes de rutear.',
        icon: Icons.fact_check_outlined,
        foreground: warningForeground,
        background: warningBackground,
        border: warningBorder,
      );
    }

    if (manualZone.id != detectedZone.id) {
      return _CompanyLocationStatus(
        kind: _CompanyLocationStatusKind.reviewZone,
        label: 'Zona por revisar',
        detail:
            'Asignada a ${manualZone.code}, pero el mapa sugiere ${detectedZone.code}. Conviene corregir antes de planear.',
        icon: Icons.fact_check_outlined,
        foreground: warningForeground,
        background: warningBackground,
        border: warningBorder,
      );
    }

    return _CompanyLocationStatus(
      kind: _CompanyLocationStatusKind.located,
      label: 'Ya ubicada',
      detail:
          'Lista para rutear dentro de ${manualZone.code} · ${manualZone.name}.',
      icon: Icons.check_circle_rounded,
      foreground: readyForeground,
      background: readyBackground,
      border: readyBorder,
    );
  }

  int _companiesAssignedToZone(String zoneId) {
    return _companyProfiles.where((row) => row.zoneId == zoneId).length;
  }

  int _companiesWithAddressInZone(String zoneId) {
    return _companyProfiles
        .where(
          (row) => row.zoneId == zoneId && row.addressLine.trim().isNotEmpty,
        )
        .length;
  }

  Color _zoneColor(String value) {
    return _zoneColorFromHex(value);
  }

  _RenderedZonePolygon? _buildRenderedZonePolygon(
    LogisticsZoneRecord zone, {
    required int fallbackIndex,
  }) {
    final explicit = _zonePolygonPointsFromRaw(zone.polygonPoints);
    final points = _resolvedZonePolygonPointsForRecord(
      zone,
      fallbackIndex: fallbackIndex,
    );
    final fallbackTemplate = explicit.length < 3 && points.length >= 3;
    if (points.length < 3) return null;

    final color = _zoneColor(zone.colorHex);
    return _RenderedZonePolygon(
      code: zone.code,
      label: zone.name,
      fillColor: color.withValues(alpha: 0.20),
      borderColor: color.withValues(alpha: 0.92),
      points: points,
      fallbackTemplate: fallbackTemplate,
    );
  }

  String _zonePolygonStatusLabel(
    LogisticsZoneRecord zone, {
    required int fallbackIndex,
  }) {
    final explicit = _zonePolygonPointsFromRaw(zone.polygonPoints);
    if (explicit.length >= 3) {
      return 'Cargado';
    }
    final templateKey = _inferZonePolygonTemplateKey(
      zone,
      fallbackIndex: fallbackIndex,
    );
    final template = _zonePolygonTemplateByKey(templateKey);
    if (template != null) {
      return 'Base ${template.code}';
    }
    return 'Pendiente';
  }

  Widget _buildTopContent(BuildContext context) {
    final palette = ServicesVisualPalette.of(context);
    final topMetrics = <MapEntry<String, String>>[
      MapEntry(
        'Empresas',
        _loading ? '...' : _companyProfiles.length.toString(),
      ),
      MapEntry('Zonas', _loading ? '...' : _zones.length.toString()),
      MapEntry(
        'Ruteables',
        _loading ? '...' : _companiesReadyForRoutingCount.toString(),
      ),
      MapEntry('Choferes', _loading ? '...' : _drivers.length.toString()),
      MapEntry('Unidades', _loading ? '...' : _vehicles.length.toString()),
      MapEntry(
        'Contenedores',
        _loading ? '...' : _companiesWithContainersCount.toString(),
      ),
    ];

    return _CatalogSurface(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1180;
          final header = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: palette.buttonGradient,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.borderStrong),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: palette.icon,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Base logística',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: palette.textPrimary,
                ),
              ),
            ],
          );

          final metrics = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: topMetrics
                .map(
                  (item) =>
                      _CompactMetricPill(label: item.key, value: item.value),
                )
                .toList(growable: false),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [header, const SizedBox(height: 10), metrics],
            );
          }

          return Row(
            children: [
              header,
              const SizedBox(width: 16),
              Expanded(
                child: Align(alignment: Alignment.centerRight, child: metrics),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCatalogRail(TabController controller) {
    final items = const <AppFolderTabItem>[
      AppFolderTabItem(label: 'Empresas', icon: Icons.apartment_rounded),
      AppFolderTabItem(label: 'Zonas y mapa', icon: Icons.map_outlined),
      AppFolderTabItem(label: 'Choferes', icon: Icons.badge_rounded),
      AppFolderTabItem(label: 'Unidades', icon: Icons.local_shipping_rounded),
      AppFolderTabItem(label: 'Contenedores', icon: Icons.recycling_rounded),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;
        final tabs = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kLogisticsSilverFooterTop, kLogisticsSilverFooterBottom],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                blurRadius: 20,
                color: Colors.black.withValues(alpha: 0.12),
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: AppFolderTabs(
            items: items,
            controller: controller,
            maxWidth: 980,
            showBottomRail: false,
          ),
        );

        if (compact) {
          return tabs;
        }

        return tabs;
      },
    );
  }

  Widget _buildCompaniesTab() {
    final rows = _filteredCompanies;
    final companyRows = rows
        .map(
          (row) => _CompanyCatalogStatusRow(
            row: row,
            status: _companyLocationStatusForRow(row),
          ),
        )
        .toList(growable: false);
    final locatedCount = companyRows
        .where(
          (entry) => entry.status.kind == _CompanyLocationStatusKind.located,
        )
        .length;
    final pendingCount = companyRows
        .where((entry) => entry.status.isPending)
        .length;
    final outsideCount = companyRows
        .where(
          (entry) =>
              entry.status.kind == _CompanyLocationStatusKind.outsidePolygon,
        )
        .length;
    final reviewCount = companyRows
        .where(
          (entry) => entry.status.kind == _CompanyLocationStatusKind.reviewZone,
        )
        .length;

    const readyForeground = Color(0xFF2F5D4E);
    const readyBackground = Color(0xFFE4F0EB);
    const readyBorder = Color(0xFFC5DACE);
    const pendingForeground = Color(0xFF7A5C1F);
    const pendingBackground = Color(0xFFF7EED8);
    const pendingBorder = Color(0xFFE6D2A4);
    const alertForeground = Color(0xFF8A3F3F);
    const alertBackground = Color(0xFFF5E3E3);
    const alertBorder = Color(0xFFD9B7B7);
    const warningForeground = Color(0xFF7A4E1F);
    const warningBackground = Color(0xFFF4E6DA);
    const warningBorder = Color(0xFFE0C3A8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CatalogSearchBar(
          title: 'Empresas activas',
          subtitle:
              'Reutiliza la base actual de clientes y ahora ya guarda perfil logístico propio sin ensuciar `sites`.',
          searchLabel: 'Buscar empresa',
          value: _companySearch,
          onChanged: (value) => setState(() => _companySearch = value),
          resultLabel:
              '${rows.length} de ${_companyProfiles.length} empresas visibles',
        ),
        const SizedBox(height: 12),
        if (companyRows.isNotEmpty) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CatalogStatusMetricChip(
                icon: Icons.check_circle_rounded,
                label: 'Ya ubicadas',
                value: locatedCount.toString(),
                helper: 'Listas para ruteo',
                foreground: readyForeground,
                background: readyBackground,
                border: readyBorder,
              ),
              _CatalogStatusMetricChip(
                icon: Icons.place_rounded,
                label: 'Pendientes',
                value: pendingCount.toString(),
                helper: 'Ubicar o asignar zona',
                foreground: pendingForeground,
                background: pendingBackground,
                border: pendingBorder,
              ),
              _CatalogStatusMetricChip(
                icon: Icons.report_problem_outlined,
                label: 'Fuera de poligono',
                value: outsideCount.toString(),
                helper: 'No caen en zonas activas',
                foreground: alertForeground,
                background: alertBackground,
                border: alertBorder,
              ),
              _CatalogStatusMetricChip(
                icon: Icons.fact_check_outlined,
                label: 'Por revisar',
                value: reviewCount.toString(),
                helper: 'Conflictos de zona',
                foreground: warningForeground,
                background: warningBackground,
                border: warningBorder,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Expanded(
          child: companyRows.isEmpty
              ? _CatalogEmptyState(
                  icon: Icons.apartment_rounded,
                  title: 'Sin empresas visibles',
                  subtitle:
                      'No hay empresas que coincidan con la búsqueda actual.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: companyRows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final entry = companyRows[index];
                    final row = entry.row;
                    return _CatalogEntityCard(
                      icon: Icons.apartment_rounded,
                      title: row.siteName,
                      subtitle:
                          'Cliente homologado desde Operación con perfil propio para Logística.',
                      statusBanner: _CompanyStatusBanner(status: entry.status),
                      tags: _companyTags(row),
                      fields: [
                        _CatalogField(
                          label: 'Dirección',
                          value: _companyAddressLabel(row),
                        ),
                        _CatalogField(
                          label: 'Zona',
                          value: _companyZoneLabel(row),
                        ),
                        _CatalogField(
                          label: 'Mapa',
                          value: _companyMapLabel(row),
                        ),
                        _CatalogField(
                          label: 'Estado',
                          value: entry.status.detail,
                        ),
                        _CatalogField(
                          label: 'Contacto',
                          value:
                              [
                                    row.operationalContact.trim(),
                                    row.contactPhone.trim(),
                                  ]
                                  .where((value) => value.isNotEmpty)
                                  .join(' · ')
                                  .isEmpty
                              ? 'Pendiente de capturar contacto operativo.'
                              : [
                                      row.operationalContact.trim(),
                                      row.contactPhone.trim(),
                                    ]
                                    .where((value) => value.isNotEmpty)
                                    .join(' · '),
                        ),
                        _CatalogField(
                          label: 'Horario',
                          value: _companyScheduleLabel(row),
                        ),
                        _CatalogField(
                          label: 'Contenedor',
                          value: _companyContainersLabel(row),
                        ),
                        _CatalogField(
                          label: 'Prioridad',
                          value: _companyPriorityLabel(row),
                        ),
                      ],
                      actions: [
                        OutlinedButton.icon(
                          onPressed: () => unawaited(_editCompanyProfile(row)),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Editar perfil'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kLogisticsSilverTextPrimary,
                            side: const BorderSide(
                              color: kLogisticsSilverBorder,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildZonesTab() {
    final zones = _filteredZones;
    final pendingZoneCompanies = _companiesPendingZoneAssignment;
    final pendingAddressCompanies = _companiesPendingAddressCapture;
    final renderedPolygons = <_RenderedZonePolygon>[];
    var zonesWithoutPolygons = 0;
    for (var i = 0; i < zones.length; i++) {
      final polygon = _buildRenderedZonePolygon(zones[i], fallbackIndex: i);
      if (polygon == null) {
        zonesWithoutPolygons++;
      } else {
        renderedPolygons.add(polygon);
      }
    }
    final zoneMetrics = <_CatalogMetricData>[
      _CatalogMetricData(
        label: 'Zonas activas',
        value: zones.length.toString(),
        helper: 'Catálogo listo para agrupar empresas',
      ),
      _CatalogMetricData(
        label: 'Empresas con dirección',
        value: _companiesWithAddressCount.toString(),
        helper: 'Ya pueden caer en mapa y zona',
      ),
      _CatalogMetricData(
        label: 'Empresas zonificadas',
        value: _companiesAssignedToZoneCount.toString(),
        helper: 'Ya listas para lectura operativa',
      ),
      _CatalogMetricData(
        label: 'Pendientes de captura',
        value: _companiesPendingZoneCaptureCount.toString(),
        helper: 'Siguen esperando dirección o zona',
      ),
    ];

    Widget buildCompanyPendingTile(
      LogisticsCompanyProfileRecord record, {
      required String reason,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.74),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kLogisticsSilverBorderLight),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: kLogisticsCapsuleGradient,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kLogisticsSilverBorderLight),
              ),
              child: const Icon(
                Icons.apartment_rounded,
                size: 18,
                color: kLogisticsSilverIcon,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.siteName,
                    style: const TextStyle(
                      fontSize: 13.6,
                      fontWeight: FontWeight.w900,
                      color: kLogisticsSilverTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reason,
                    style: const TextStyle(
                      fontSize: 11.8,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: kLogisticsSilverTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => unawaited(_editCompanyProfile(record)),
              style: OutlinedButton.styleFrom(
                foregroundColor: kLogisticsSilverTextPrimary,
                side: const BorderSide(color: kLogisticsSilverBorder),
              ),
              child: const Text('Abrir'),
            ),
          ],
        ),
      );
    }

    Widget buildZoneTile(LogisticsZoneRecord zone, int index) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kLogisticsSilverBorderLight),
          boxShadow: [
            BoxShadow(
              blurRadius: 14,
              color: Colors.black.withValues(alpha: 0.06),
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: _zoneColor(zone.colorHex),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zone.name,
                        style: const TextStyle(
                          fontSize: 14.2,
                          fontWeight: FontWeight.w900,
                          color: kLogisticsSilverTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${zone.code} · ${zone.city}, ${zone.state}',
                        style: const TextStyle(
                          fontSize: 11.8,
                          fontWeight: FontWeight.w700,
                          color: kLogisticsSilverTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => unawaited(_editZone(zone)),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Editar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kLogisticsSilverTextPrimary,
                    side: const BorderSide(color: kLogisticsSilverBorder),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CompactMetricPill(
                  label: 'Asignadas',
                  value: _companiesAssignedToZone(zone.id).toString(),
                ),
                _CompactMetricPill(
                  label: 'Con dirección',
                  value: _companiesWithAddressInZone(zone.id).toString(),
                ),
                _CompactMetricPill(
                  label: 'Polígono',
                  value: _zonePolygonStatusLabel(zone, fallbackIndex: index),
                ),
                _CompactMetricPill(label: 'Color', value: zone.colorHex),
              ],
            ),
            if (zone.coverageHint.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                zone.coverageHint.trim(),
                style: const TextStyle(
                  fontSize: 11.8,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: kLogisticsSilverTextSecondary,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1260;
        final sideWidth = constraints.maxWidth > 1500 ? 460.0 : 420.0;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 880.0;
        final compactMapHeight = (availableHeight * 0.46)
            .clamp(300.0, 460.0)
            .toDouble();

        final mapPanel = _CatalogSurface(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                Positioned.fill(
                  child: FlutterMap(
                    options: const MapOptions(
                      initialCenter: LatLng(20.5235, -100.8157),
                      initialZoom: 10.9,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.dicsa.operacion',
                      ),
                      PolygonLayer(
                        polygons: renderedPolygons
                            .map(
                              (polygon) => Polygon(
                                points: polygon.points,
                                color: polygon.fillColor,
                                borderColor: polygon.borderColor,
                                borderStrokeWidth: 2.0,
                                label: '${polygon.code}\n${polygon.label}',
                                labelStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: kLogisticsSilverTextPrimary,
                                ),
                                rotateLabel: false,
                              ),
                            )
                            .toList(growable: false),
                      ),
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution(
                            'OpenStreetMap contributors',
                            onTap: () {
                              unawaited(
                                launchUrl(
                                  Uri.parse(
                                    'https://openstreetmap.org/copyright',
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 360),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.84),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: kLogisticsSilverBorderLight),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 18,
                          color: Colors.black.withValues(alpha: 0.10),
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Mapa por polígonos',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: kLogisticsSilverTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _CompactMetricPill(
                              label: 'Visibles',
                              value: renderedPolygons.length.toString(),
                            ),
                            _CompactMetricPill(
                              label: 'Sin polígono',
                              value: zonesWithoutPolygons.toString(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 260),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.84),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: kLogisticsSilverBorderLight),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: renderedPolygons
                          .map(
                            (polygon) => _ZoneLegendChip(
                              code: polygon.code,
                              label: polygon.label,
                              color: polygon.borderColor,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        final sidePanel = _CatalogSurface(
          padding: const EdgeInsets.all(16),
          child: Scrollbar(
            controller: _zonesScrollController,
            thumbVisibility: true,
            child: ListView(
              controller: _zonesScrollController,
              primary: false,
              padding: EdgeInsets.zero,
              children: [
                const Text(
                  'Asignación de zonas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: kLogisticsSilverTextPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                if (compact)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        onChanged: (value) =>
                            setState(() => _zoneSearch = value),
                        controller: TextEditingController(text: _zoneSearch)
                          ..selection = TextSelection.collapsed(
                            offset: _zoneSearch.length,
                          ),
                        decoration: InputDecoration(
                          labelText: 'Buscar zona',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.72),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: kLogisticsSilverBorder,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: kLogisticsSilverBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: kLogisticsSilverTextPrimary,
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: () => unawaited(_createZone()),
                        style: FilledButton.styleFrom(
                          backgroundColor: kLogisticsSilverTextPrimary,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: const Text('Crear zona'),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (value) =>
                              setState(() => _zoneSearch = value),
                          controller: TextEditingController(text: _zoneSearch)
                            ..selection = TextSelection.collapsed(
                              offset: _zoneSearch.length,
                            ),
                          decoration: InputDecoration(
                            labelText: 'Buscar zona',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.72),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: kLogisticsSilverBorder,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: kLogisticsSilverBorder,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: kLogisticsSilverTextPrimary,
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: () => unawaited(_createZone()),
                        style: FilledButton.styleFrom(
                          backgroundColor: kLogisticsSilverTextPrimary,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: const Text('Crear zona'),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: zoneMetrics
                      .map((item) => _CatalogMetricChip(data: item))
                      .toList(growable: false),
                ),
                const SizedBox(height: 12),
                if (zones.isEmpty)
                  _CatalogEmptyState(
                    icon: Icons.grid_view_rounded,
                    title: 'Todavía no hay zonas definidas',
                    subtitle:
                        'Puedes crear primero los sectores base de Celaya y después ir asignando empresas conforme capturen dirección.',
                    actionLabel: 'Crear primera zona',
                    onAction: () => unawaited(_createZone()),
                  )
                else ...[
                  const Text(
                    'Zonas activas',
                    style: TextStyle(
                      fontSize: 14.8,
                      fontWeight: FontWeight.w900,
                      color: kLogisticsSilverTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < zones.length; i++)
                    buildZoneTile(zones[i], i),
                ],
                if (pendingZoneCompanies.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Empresas listas para zonificar',
                    style: TextStyle(
                      fontSize: 14.8,
                      fontWeight: FontWeight.w900,
                      color: kLogisticsSilverTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ya tienen dirección, pero todavía no zona.',
                    style: TextStyle(
                      fontSize: 11.8,
                      fontWeight: FontWeight.w600,
                      color: kLogisticsSilverTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...pendingZoneCompanies
                      .take(6)
                      .map(
                        (record) => buildCompanyPendingTile(
                          record,
                          reason: _companyAddressLabel(record),
                        ),
                      ),
                ],
                if (pendingAddressCompanies.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Empresas que siguen sin dirección',
                    style: TextStyle(
                      fontSize: 14.8,
                      fontWeight: FontWeight.w900,
                      color: kLogisticsSilverTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Todavía no pueden caer en mapa ni cuadrante.',
                    style: TextStyle(
                      fontSize: 11.8,
                      fontWeight: FontWeight.w600,
                      color: kLogisticsSilverTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...pendingAddressCompanies
                      .take(6)
                      .map(
                        (record) => buildCompanyPendingTile(
                          record,
                          reason:
                              'Falta capturar dirección para ubicarla dentro del mapa.',
                        ),
                      ),
                ],
              ],
            ),
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: compactMapHeight, child: mapPanel),
              const SizedBox(height: 12),
              Expanded(child: sidePanel),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 10, child: mapPanel),
            const SizedBox(width: 12),
            SizedBox(width: sideWidth, child: sidePanel),
          ],
        );
      },
    );
  }

  Widget _buildDriversTab() {
    final rows = _filteredDrivers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CatalogSearchBar(
          title: 'Choferes base',
          subtitle:
              'La siguiente fase aquí es compatibilidad por tipo de unidad y disponibilidad real.',
          searchLabel: 'Buscar chofer',
          value: _driverSearch,
          onChanged: (value) => setState(() => _driverSearch = value),
          resultLabel: '${rows.length} de ${_drivers.length} choferes visibles',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: rows.isEmpty
              ? _CatalogEmptyState(
                  icon: Icons.badge_rounded,
                  title: 'Sin choferes visibles',
                  subtitle:
                      'No hay choferes que coincidan con la búsqueda actual.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return _CatalogEntityCard(
                      icon: Icons.badge_rounded,
                      title: (row['full_name'] ?? 'SIN NOMBRE').toString(),
                      subtitle:
                          'Chofer activo reutilizado desde catálogo base.',
                      tags: const ['Activo', 'Chofer'],
                      fields: [
                        _CatalogField(
                          label: 'Compatibilidad',
                          value:
                              'Pendiente: camión, camioneta, pick up, grúa, trailer',
                        ),
                        _CatalogField(
                          label: 'Disponibilidad',
                          value: 'Siguiente fase: turno, descansos y cobertura',
                        ),
                        _CatalogField(
                          label: 'Uso en Logística',
                          value: 'Asignación por ruta, prioridad y zona',
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildVehiclesTab() {
    final rows = _filteredVehicles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CatalogSearchBar(
          title: 'Unidades activas',
          subtitle:
              'Reutiliza FLOTILLA, pero empieza a leer las unidades con lógica de Logística y no solo mantenimiento.',
          searchLabel: 'Buscar unidad',
          value: _vehicleSearch,
          onChanged: (value) => setState(() => _vehicleSearch = value),
          resultLabel:
              '${rows.length} de ${_vehicles.length} unidades visibles',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: rows.isEmpty
              ? _CatalogEmptyState(
                  icon: Icons.local_shipping_rounded,
                  title: 'Sin unidades visibles',
                  subtitle:
                      'No hay unidades que coincidan con la búsqueda actual.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final serial = (row['serial_number'] ?? '')
                        .toString()
                        .trim();
                    return _CatalogEntityCard(
                      icon: Icons.local_shipping_rounded,
                      title: (row['code'] ?? 'SIN CÓDIGO').toString(),
                      subtitle: serial.isEmpty
                          ? 'Unidad activa sin serie visible.'
                          : 'Serie: $serial',
                      tags: [
                        _prettyLabel((row['status'] ?? 'activo').toString()),
                        _prettyLabel((row['type'] ?? 'unidad').toString()),
                      ],
                      fields: [
                        _CatalogField(
                          label: 'Tipo logístico',
                          value:
                              'Pendiente: camión, camioneta, pick up, grúa o trailer',
                        ),
                        _CatalogField(
                          label: 'Compatibilidad',
                          value:
                              'Siguiente fase: contenedor, carga o servicio permitido',
                        ),
                        _CatalogField(
                          label: 'Base operativa',
                          value:
                              'Lectura homologada desde FLOTILLA y mantenimiento',
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildContainersTab() {
    return Scrollbar(
      controller: _containersScrollController,
      child: ListView(
        controller: _containersScrollController,
        primary: false,
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          _CatalogSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Contenedores como prioridad operativa',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: kLogisticsSilverTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Este catálogo definirá dónde están los contenedores, cuántos hay, qué capacidad tienen y qué tan urgente es cada recolección. Aquí nacerá buena parte de la priorización real del día.',
                  style: TextStyle(
                    fontSize: 12.8,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: kLogisticsSilverTextSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: const [
                    _CatalogMetricChip(
                      data: _CatalogMetricData(
                        label: 'Empresa',
                        value: 'Obligatorio',
                        helper: 'Quién tiene el contenedor',
                      ),
                    ),
                    _CatalogMetricChip(
                      data: _CatalogMetricData(
                        label: 'Capacidad',
                        value: 'Obligatorio',
                        helper: 'Volumen o tipo de carga',
                      ),
                    ),
                    _CatalogMetricChip(
                      data: _CatalogMetricData(
                        label: 'Urgencia',
                        value: 'Operativa',
                        helper: 'Tolerancia a recolección tardía',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              _CatalogBlueprintCard(
                icon: Icons.location_on_outlined,
                title: 'Dónde está',
                lines: [
                  'Empresa o patio actual',
                  'Zona o sector',
                  'Ubicación confirmada',
                ],
              ),
              _CatalogBlueprintCard(
                icon: Icons.straighten_rounded,
                title: 'Qué capacidad tiene',
                lines: [
                  'Tipo de contenedor',
                  'Capacidad estimada',
                  'Compatibilidad con unidad',
                ],
              ),
              _CatalogBlueprintCard(
                icon: Icons.priority_high_rounded,
                title: 'Qué tan urgente es',
                lines: [
                  'Volumen esperado',
                  'Última recolección',
                  'Si tolera retraso o no',
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadError() {
    return _CatalogEmptyState(
      icon: Icons.error_outline_rounded,
      title: 'No se pudieron cargar los catálogos',
      subtitle: _loadError ?? 'Ocurrió un error inesperado.',
      actionLabel: 'Reintentar',
      onAction: () {
        setState(() {
          _loading = true;
          _loadError = null;
        });
        unawaited(_bootstrap());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ServicesVisualModeScope(
      logisticsSilverMode: true,
      child: AreaThemeScope(
        tokens: logisticsAreaTokens,
        child: DefaultTabController(
          length: 5,
          child: ServicesShell(
            headerTitle: 'Catálogos Operativos',
            servicesNavLabel: kLogisticsNavCatalogsLabel,
            customSideMenuBuilder: (context, closeMenu) =>
                LogisticsAreaSidePanel(
                  currentLabel: kLogisticsNavCatalogsLabel,
                  canReturnToDirection: _canReturnToDirection,
                  onNavigate: (label) {
                    closeMenu();
                    _handleNavigationAction(label);
                  },
                ),
            sideMenuWidth: kLogisticsSideMenuWidth,
            topContent: Builder(
              builder: (topContext) {
                return _buildTopContent(topContext);
              },
            ),
            scrollTopContentWhenNeeded: true,
            minMainContentHeight: 360,
            activeOverlayModule: ServicesOverlayNavModule.servicios,
            onLogout: () async => signOutAndRouteToLogin(context),
            onGoToGeneralDashboard: _openDirectionDashboard,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Builder(
                    builder: (tabContext) {
                      final controller = DefaultTabController.of(tabContext);
                      return AnimatedBuilder(
                        animation: controller.animation!,
                        builder: (context, child) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                              child: _buildCatalogRail(controller),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: _loadError != null
                                    ? _buildLoadError()
                                    : TabBarView(
                                        children: [
                                          _buildCompaniesTab(),
                                          _buildZonesTab(),
                                          _buildDriversTab(),
                                          _buildVehiclesTab(),
                                          _buildContainersTab(),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _CatalogMetricData {
  final String label;
  final String value;
  final String helper;

  const _CatalogMetricData({
    required this.label,
    required this.value,
    required this.helper,
  });
}

class _CatalogField {
  final String label;
  final String value;

  const _CatalogField({required this.label, required this.value});
}

class _CatalogSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _CatalogSurface({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: kLogisticsPanelGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kLogisticsSilverBorder),
        boxShadow: [
          BoxShadow(
            blurRadius: 22,
            color: Colors.black.withValues(alpha: 0.10),
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            blurRadius: 28,
            color: kLogisticsSilverGlowEdge.withValues(alpha: 0.28),
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CatalogMetricChip extends StatelessWidget {
  final _CatalogMetricData data;

  const _CatalogMetricChip({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: kLogisticsCapsuleGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kLogisticsSilverBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            data.label,
            style: const TextStyle(
              fontSize: 11.4,
              fontWeight: FontWeight.w800,
              color: kLogisticsSilverTextMuted,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            data.value,
            style: const TextStyle(
              fontSize: 14.2,
              fontWeight: FontWeight.w900,
              color: kLogisticsSilverTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.helper,
            style: const TextStyle(
              fontSize: 11.2,
              fontWeight: FontWeight.w600,
              color: kLogisticsSilverTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactMetricPill extends StatelessWidget {
  final String label;
  final String value;

  const _CompactMetricPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: kLogisticsSilverSurfaceInteractive,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kLogisticsSilverBorderLight),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 11.2,
          fontWeight: FontWeight.w800,
          color: kLogisticsSilverTextPrimary,
        ),
      ),
    );
  }
}

class _ZoneLegendChip extends StatelessWidget {
  final String code;
  final String label;
  final Color color;

  const _ZoneLegendChip({
    required this.code,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kLogisticsSilverBorderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$code · $label',
            style: const TextStyle(
              fontSize: 11.2,
              fontWeight: FontWeight.w800,
              color: kLogisticsSilverTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogSearchBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final String searchLabel;
  final String value;
  final ValueChanged<String> onChanged;
  final String resultLabel;

  const _CatalogSearchBar({
    required this.title,
    required this.subtitle,
    required this.searchLabel,
    required this.value,
    required this.onChanged,
    required this.resultLabel,
  });

  @override
  Widget build(BuildContext context) {
    return _CatalogSurface(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: kLogisticsSilverTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                resultLabel,
                style: const TextStyle(
                  fontSize: 11.6,
                  fontWeight: FontWeight.w700,
                  color: kLogisticsSilverTextMuted,
                ),
              ),
            ],
          );

          final search = SizedBox(
            width: compact ? double.infinity : 320,
            child: TextField(
              onChanged: onChanged,
              controller: TextEditingController(text: value)
                ..selection = TextSelection.collapsed(offset: value.length),
              decoration: InputDecoration(
                labelText: searchLabel,
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.72),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: kLogisticsSilverBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: kLogisticsSilverBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: kLogisticsSilverTextPrimary,
                    width: 1.2,
                  ),
                ),
              ),
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [info, const SizedBox(height: 10), search],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: info),
              const SizedBox(width: 12),
              search,
            ],
          );
        },
      ),
    );
  }
}

class _CatalogEntityCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? statusBanner;
  final List<String> tags;
  final List<_CatalogField> fields;
  final List<Widget> actions;

  const _CatalogEntityCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.statusBanner,
    required this.tags,
    required this.fields,
    this.actions = const <Widget>[],
  });

  @override
  Widget build(BuildContext context) {
    return _CatalogSurface(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: kLogisticsCapsuleGradient,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kLogisticsSilverBorderLight),
                ),
                child: Icon(icon, size: 22, color: kLogisticsSilverIcon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: kLogisticsSilverTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.4,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: kLogisticsSilverTextSecondary,
                      ),
                    ),
                    if (statusBanner != null) ...[
                      const SizedBox(height: 8),
                      statusBanner!,
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags
                .map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: kLogisticsSilverSurfaceInteractive,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: kLogisticsSilverBorderLight),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        fontSize: 11.2,
                        fontWeight: FontWeight.w800,
                        color: kLogisticsSilverTextPrimary,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 12),
          ...fields.map(
            (field) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 124,
                    child: Text(
                      field.label,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: kLogisticsSilverTextMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      field.value,
                      style: const TextStyle(
                        fontSize: 12.4,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: kLogisticsSilverTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 10, runSpacing: 10, children: actions),
          ],
        ],
      ),
    );
  }
}

class _CompanyStatusBanner extends StatelessWidget {
  final _CompanyLocationStatus status;

  const _CompanyStatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: status.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(status.icon, size: 18, color: status.foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 12.2,
                    fontWeight: FontWeight.w900,
                    color: status.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status.detail,
                  style: TextStyle(
                    fontSize: 11.4,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: status.foreground.withValues(alpha: 0.88),
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

class _CatalogStatusMetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String helper;
  final Color foreground;
  final Color background;
  final Color border;

  const _CatalogStatusMetricChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.helper,
    required this.foreground,
    required this.background,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 178),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.8,
                  fontWeight: FontWeight.w900,
                  color: foreground,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14.4,
                  fontWeight: FontWeight.w900,
                  color: foreground,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                helper,
                style: TextStyle(
                  fontSize: 11.0,
                  fontWeight: FontWeight.w700,
                  color: foreground.withValues(alpha: 0.84),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogisticsCompanyProfileEditorDialog extends StatefulWidget {
  final LogisticsCompanyProfileRecord record;
  final List<LogisticsZoneRecord> zones;

  const _LogisticsCompanyProfileEditorDialog({
    required this.record,
    required this.zones,
  });

  @override
  State<_LogisticsCompanyProfileEditorDialog> createState() =>
      _LogisticsCompanyProfileEditorDialogState();
}

class _LogisticsCompanyProfileEditorDialogState
    extends State<_LogisticsCompanyProfileEditorDialog> {
  late final TextEditingController _contactController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _referenceController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _zoneNotesController;
  late final TextEditingController _pickupWindowController;
  late final TextEditingController _containerCountController;
  late final TextEditingController _containerCapacityController;
  late final TextEditingController _notesController;

  late String _selectedZoneId;
  late String _scheduleFlexibility;
  late String _collectionUrgency;
  late String _volumePressure;
  late bool _earlyPickupRequired;
  late bool _hasContainers;
  bool _geocoding = false;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _contactController = TextEditingController(text: record.operationalContact);
    _phoneController = TextEditingController(text: record.contactPhone);
    _addressController = TextEditingController(text: record.addressLine);
    _referenceController = TextEditingController(text: record.addressReference);
    _latitudeController = TextEditingController(
      text: record.latitude?.toStringAsFixed(6) ?? '',
    );
    _longitudeController = TextEditingController(
      text: record.longitude?.toStringAsFixed(6) ?? '',
    );
    _zoneNotesController = TextEditingController(text: record.zoneNotes);
    _pickupWindowController = TextEditingController(text: record.pickupWindow);
    _containerCountController = TextEditingController(
      text: record.hasContainers ? record.containerCount.toString() : '',
    );
    _containerCapacityController = TextEditingController(
      text: record.containerCapacityNote,
    );
    _notesController = TextEditingController(text: record.notes);
    _selectedZoneId = record.zoneId ?? '';
    _scheduleFlexibility = record.scheduleFlexibility;
    _collectionUrgency = record.collectionUrgency;
    _volumePressure = record.volumePressure;
    _earlyPickupRequired = record.earlyPickupRequired;
    _hasContainers = record.hasContainers;
  }

  @override
  void dispose() {
    _contactController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _referenceController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _zoneNotesController.dispose();
    _pickupWindowController.dispose();
    _containerCountController.dispose();
    _containerCapacityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label, {String? helperText}) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.70),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kLogisticsSilverBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kLogisticsSilverBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: kLogisticsSilverTextPrimary,
          width: 1.2,
        ),
      ),
    );
  }

  List<LogisticsZoneRecord> get _activeZones {
    return widget.zones.where((zone) => zone.active).toList(growable: false);
  }

  double? _parseCoordinate(TextEditingController controller) {
    return double.tryParse(controller.text.trim());
  }

  LatLng? _currentPoint() {
    final latitude = _parseCoordinate(_latitudeController);
    final longitude = _parseCoordinate(_longitudeController);
    if (latitude == null || longitude == null) return null;
    return LatLng(latitude, longitude);
  }

  _ZoneDetectionResult? _zoneDetection() {
    final point = _currentPoint();
    if (point == null) return null;
    return _detectZoneForCoordinate(point: point, zones: _activeZones);
  }

  Future<void> _pickPointOnMap() async {
    final picked = await showDialog<LatLng>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CompanyLocationPickerDialog(
        companyName: widget.record.siteName,
        zones: _activeZones,
        initialPoint: _currentPoint(),
      ),
    );
    if (picked == null) return;
    setState(() {
      _latitudeController.text = picked.latitude.toStringAsFixed(6);
      _longitudeController.text = picked.longitude.toStringAsFixed(6);
    });
  }

  String _buildGeocodingQuery() {
    final parts = <String>[
      _addressController.text.trim(),
      _referenceController.text.trim(),
    ].where((part) => part.isNotEmpty).toList(growable: true);
    if (parts.isEmpty) return '';

    final probe = parts.join(', ').toLowerCase();
    if (!probe.contains('guanajuato')) {
      parts.add('Guanajuato');
    }
    if (!probe.contains('mexico') && !probe.contains('méxico')) {
      parts.add('Mexico');
    }
    return parts.join(', ');
  }

  void _applyGeocodingCandidate(LogisticsGeocodingCandidate candidate) {
    setState(() {
      _latitudeController.text = candidate.point.latitude.toStringAsFixed(6);
      _longitudeController.text = candidate.point.longitude.toStringAsFixed(6);
      _validationMessage = null;
    });
  }

  Future<void> _runAddressGeocoding() async {
    if (_geocoding) return;

    final query = _buildGeocodingQuery();
    if (query.isEmpty) {
      setState(() {
        _validationMessage =
            'Primero captura una direccion para poder ubicar la empresa.';
      });
      return;
    }

    setState(() {
      _geocoding = true;
      _validationMessage = null;
    });

    try {
      final candidates = await LogisticsGeocodingService.searchAddress(query);
      if (!mounted) return;

      if (candidates.isEmpty) {
        setState(() {
          _validationMessage =
              'No encontramos coincidencias para esa direccion. Conviene revisar la captura o marcar el punto manualmente en el mapa.';
        });
        return;
      }

      if (candidates.length == 1) {
        _applyGeocodingCandidate(candidates.first);
        return;
      }

      final selected = await showDialog<LogisticsGeocodingCandidate>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CompanyGeocodingResultsDialog(
          companyName: widget.record.siteName,
          candidates: candidates,
        ),
      );
      if (!mounted || selected == null) return;
      _applyGeocodingCandidate(selected);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _validationMessage =
            'No se pudo consultar la direccion en el mapa: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _geocoding = false);
      }
    }
  }

  void _submit() {
    final parsedContainerCount =
        int.tryParse(_containerCountController.text.trim()) ?? 0;
    final latitudeRaw = _latitudeController.text.trim();
    final longitudeRaw = _longitudeController.text.trim();
    final parsedLatitude = latitudeRaw.isEmpty
        ? null
        : _parseCoordinate(_latitudeController);
    final parsedLongitude = longitudeRaw.isEmpty
        ? null
        : _parseCoordinate(_longitudeController);
    if (latitudeRaw.isNotEmpty != longitudeRaw.isNotEmpty) {
      setState(() {
        _validationMessage =
            'La ubicación necesita latitud y longitud completas.';
      });
      return;
    }
    if ((latitudeRaw.isNotEmpty && parsedLatitude == null) ||
        (longitudeRaw.isNotEmpty && parsedLongitude == null)) {
      setState(() {
        _validationMessage = 'Las coordenadas no tienen un formato válido.';
      });
      return;
    }
    if (parsedLatitude != null &&
        (parsedLatitude < -90 || parsedLatitude > 90)) {
      setState(() {
        _validationMessage = 'La latitud debe quedar entre -90 y 90.';
      });
      return;
    }
    if (parsedLongitude != null &&
        (parsedLongitude < -180 || parsedLongitude > 180)) {
      setState(() {
        _validationMessage = 'La longitud debe quedar entre -180 y 180.';
      });
      return;
    }

    final detection = _zoneDetection();
    var resolvedZoneId = _selectedZoneId.trim();
    if (resolvedZoneId.isEmpty && detection?.hasSingleMatch == true) {
      resolvedZoneId = detection!.singleMatch!.id;
    }
    _validationMessage = null;
    Navigator.of(context).pop(
      widget.record.copyWith(
        zoneId: resolvedZoneId.isEmpty ? null : resolvedZoneId,
        clearZoneId: resolvedZoneId.isEmpty,
        zoneNotes: resolvedZoneId.isEmpty
            ? ''
            : _zoneNotesController.text.trim(),
        latitude: parsedLatitude,
        clearLatitude: parsedLatitude == null,
        longitude: parsedLongitude,
        clearLongitude: parsedLongitude == null,
        operationalContact: _contactController.text.trim(),
        contactPhone: _phoneController.text.trim(),
        addressLine: _addressController.text.trim(),
        addressReference: _referenceController.text.trim(),
        pickupWindow: _pickupWindowController.text.trim(),
        scheduleFlexibility: _scheduleFlexibility,
        earlyPickupRequired: _earlyPickupRequired,
        hasContainers: _hasContainers,
        containerCount: _hasContainers ? parsedContainerCount : 0,
        containerCapacityNote: _containerCapacityController.text.trim(),
        collectionUrgency: _collectionUrgency,
        volumePressure: _volumePressure,
        notes: _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final detection = _zoneDetection();
    final suggestedZone = detection?.singleMatch;
    final manualZone = _selectedZoneId.trim().isEmpty
        ? null
        : widget.zones.cast<LogisticsZoneRecord?>().firstWhere(
            (zone) => zone?.id == _selectedZoneId.trim(),
            orElse: () => null,
          );
    final hasCoordinateText =
        _latitudeController.text.trim().isNotEmpty ||
        _longitudeController.text.trim().isNotEmpty;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: _CatalogSurface(
          padding: const EdgeInsets.all(18),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Perfil logístico de ${widget.record.siteName}',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: kLogisticsSilverTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Aquí capturamos solo atributos de Logística. La empresa sigue viviendo en `sites` para no duplicar ni romper el catálogo maestro.',
                  style: TextStyle(
                    fontSize: 12.6,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: kLogisticsSilverTextSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 320,
                      child: TextField(
                        controller: _contactController,
                        decoration: _decoration('Contacto operativo'),
                      ),
                    ),
                    SizedBox(
                      width: 240,
                      child: TextField(
                        controller: _phoneController,
                        decoration: _decoration('Teléfono'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressController,
                  decoration: _decoration(
                    'Dirección',
                    helperText: 'Será la base para el mapa y la zonificación.',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _referenceController,
                  decoration: _decoration('Referencia'),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: kLogisticsSilverBorderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 200,
                            child: TextField(
                              controller: _latitudeController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                              decoration: _decoration('Latitud'),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          SizedBox(
                            width: 200,
                            child: TextField(
                              controller: _longitudeController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                              decoration: _decoration('Longitud'),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _geocoding
                                      ? null
                                      : () => unawaited(_runAddressGeocoding()),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        kLogisticsSilverTextPrimary,
                                    side: const BorderSide(
                                      color: kLogisticsSilverBorder,
                                    ),
                                  ),
                                  icon: _geocoding
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.1,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.travel_explore_rounded,
                                          size: 18,
                                        ),
                                  label: Text(
                                    _geocoding
                                        ? 'Buscando...'
                                        : 'Buscar direccion',
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _geocoding
                                      ? null
                                      : () => unawaited(_pickPointOnMap()),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        kLogisticsSilverTextPrimary,
                                    side: const BorderSide(
                                      color: kLogisticsSilverBorder,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.place_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Elegir en mapa'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'La busqueda por direccion corre una empresa a la vez y deja cache local para no castigar el servicio del mapa.',
                        style: TextStyle(
                          fontSize: 11.8,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: kLogisticsSilverTextMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (!hasCoordinateText)
                        const Text(
                          'Captura o marca un punto para validar la empresa contra los polígonos de zona.',
                          style: TextStyle(
                            fontSize: 12.2,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: kLogisticsSilverTextSecondary,
                          ),
                        )
                      else if (_latitudeController.text.trim().isEmpty !=
                          _longitudeController.text.trim().isEmpty)
                        const Text(
                          'La ubicación necesita latitud y longitud completas.',
                          style: TextStyle(
                            fontSize: 12.2,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8A5A3F),
                          ),
                        )
                      else if (detection == null)
                        const Text(
                          'Las coordenadas no son válidas todavía.',
                          style: TextStyle(
                            fontSize: 12.2,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8A5A3F),
                          ),
                        )
                      else if (detection.hasSingleMatch)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Zona detectada por mapa: ${suggestedZone!.code} · ${suggestedZone.name}',
                              style: const TextStyle(
                                fontSize: 12.4,
                                height: 1.4,
                                fontWeight: FontWeight.w800,
                                color: kLogisticsSilverTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _CompactMetricPill(
                                  label: 'Lat',
                                  value: detection.point.latitude
                                      .toStringAsFixed(5),
                                ),
                                _CompactMetricPill(
                                  label: 'Lng',
                                  value: detection.point.longitude
                                      .toStringAsFixed(5),
                                ),
                                if (_selectedZoneId.trim() != suggestedZone.id)
                                  FilledButton.tonalIcon(
                                    onPressed: () {
                                      setState(
                                        () =>
                                            _selectedZoneId = suggestedZone.id,
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.auto_fix_high_rounded,
                                    ),
                                    label: const Text('Usar zona sugerida'),
                                  ),
                              ],
                            ),
                          ],
                        )
                      else if (detection.hasMultipleMatches)
                        Text(
                          'La ubicación cae en varias zonas activas: ${detection.matches.map((zone) => zone.code).join(', ')}. Conviene revisar polígonos antes de asignar.',
                          style: const TextStyle(
                            fontSize: 12.2,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8A5A3F),
                          ),
                        )
                      else
                        const Text(
                          'La ubicación no cae dentro de ninguna zona activa todavía.',
                          style: TextStyle(
                            fontSize: 12.2,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8A5A3F),
                          ),
                        ),
                      if (manualZone != null &&
                          suggestedZone != null &&
                          manualZone.id != suggestedZone.id) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Zona manual actual: ${manualZone.code} · ${manualZone.name}. La detección del mapa sugiere otra zona.',
                          style: const TextStyle(
                            fontSize: 12.0,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8A5A3F),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (widget.zones.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: kLogisticsSilverBorderLight),
                    ),
                    child: const Text(
                      'Todavía no hay zonas creadas. Primero defínelas en el tab de Zonas y mapa y después podrás asignarlas aquí.',
                      style: TextStyle(
                        fontSize: 12.4,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: kLogisticsSilverTextSecondary,
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 260,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedZoneId.isEmpty
                              ? ''
                              : _selectedZoneId,
                          decoration: _decoration('Zona'),
                          items: [
                            const DropdownMenuItem<String>(
                              value: '',
                              child: Text('Sin zona asignada'),
                            ),
                            ...widget.zones.map(
                              (zone) => DropdownMenuItem<String>(
                                value: zone.id,
                                child: Text('${zone.code} · ${zone.name}'),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedZoneId = value ?? '');
                          },
                        ),
                      ),
                      SizedBox(
                        width: 360,
                        child: TextField(
                          controller: _zoneNotesController,
                          enabled: _selectedZoneId.trim().isNotEmpty,
                          decoration: _decoration(
                            'Nota de zona',
                            helperText:
                                'Acceso, referencia o detalle específico del sector.',
                          ),
                        ),
                      ),
                    ],
                  ),
                if (_validationMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _validationMessage!,
                    style: const TextStyle(
                      fontSize: 12.2,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8A3F3F),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 240,
                      child: TextField(
                        controller: _pickupWindowController,
                        decoration: _decoration(
                          'Ventana de recolección',
                          helperText: 'Ejemplo: 6:00-8:00 a.m.',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        initialValue: _scheduleFlexibility,
                        decoration: _decoration('Flexibilidad'),
                        items: kLogisticsScheduleFlexibilityOptions
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  logisticsScheduleFlexibilityLabel(value),
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _scheduleFlexibility = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: _earlyPickupRequired,
                  onChanged: (value) {
                    setState(() => _earlyPickupRequired = value);
                  },
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: kLogisticsSilverTextPrimary,
                  title: const Text(
                    'Requiere recolección temprana',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: kLogisticsSilverTextPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'Marca las empresas que de verdad no toleran recolección tardía.',
                    style: TextStyle(
                      fontSize: 12.2,
                      fontWeight: FontWeight.w600,
                      color: kLogisticsSilverTextSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SwitchListTile.adaptive(
                  value: _hasContainers,
                  onChanged: (value) {
                    setState(() => _hasContainers = value);
                  },
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: kLogisticsSilverTextPrimary,
                  title: const Text(
                    'Tiene contenedores',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: kLogisticsSilverTextPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'Activa la lectura de cantidad y capacidad para priorización.',
                    style: TextStyle(
                      fontSize: 12.2,
                      fontWeight: FontWeight.w600,
                      color: kLogisticsSilverTextSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 180,
                      child: TextField(
                        controller: _containerCountController,
                        enabled: _hasContainers,
                        keyboardType: TextInputType.number,
                        decoration: _decoration('Cantidad de contenedores'),
                      ),
                    ),
                    SizedBox(
                      width: 360,
                      child: TextField(
                        controller: _containerCapacityController,
                        enabled: _hasContainers,
                        decoration: _decoration(
                          'Capacidad o nota del contenedor',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        initialValue: _collectionUrgency,
                        decoration: _decoration('Urgencia'),
                        items: kLogisticsCollectionUrgencyOptions
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  logisticsCollectionUrgencyLabel(value),
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _collectionUrgency = value);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        initialValue: _volumePressure,
                        decoration: _decoration('Presión de volumen'),
                        items: kLogisticsVolumePressureOptions
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  logisticsVolumePressureLabel(value),
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _volumePressure = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  maxLines: 4,
                  decoration: _decoration(
                    'Notas operativas',
                    helperText:
                        'Aquí puedes anotar negociación, restricciones o contexto.',
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: kLogisticsSilverTextPrimary,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Guardar perfil'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompanyGeocodingResultsDialog extends StatelessWidget {
  final String companyName;
  final List<LogisticsGeocodingCandidate> candidates;

  const _CompanyGeocodingResultsDialog({
    required this.companyName,
    required this.candidates,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 620),
        child: _CatalogSurface(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Coincidencias para $companyName',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: kLogisticsSilverTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Selecciona la ubicacion correcta antes de guardar la empresa. Si ninguna coincide, vuelve y usa el mapa manual.',
                style: TextStyle(
                  fontSize: 12.6,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: kLogisticsSilverTextSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final candidate = candidates[index];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.of(context).pop(candidate),
                        child: Ink(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: kLogisticsCapsuleGradient,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: kLogisticsSilverBorderLight,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: kLogisticsSilverSurfaceInteractive,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: kLogisticsSilverBorderLight,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.place_rounded,
                                  color: kLogisticsSilverIcon,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      candidate.primaryLabel,
                                      style: const TextStyle(
                                        fontSize: 14.2,
                                        height: 1.35,
                                        fontWeight: FontWeight.w900,
                                        color: kLogisticsSilverTextPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      candidate.secondaryLabel,
                                      style: const TextStyle(
                                        fontSize: 11.9,
                                        height: 1.4,
                                        fontWeight: FontWeight.w600,
                                        color: kLogisticsSilverTextSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _CompactMetricPill(
                                          label: 'Lat',
                                          value: candidate.point.latitude
                                              .toStringAsFixed(5),
                                        ),
                                        _CompactMetricPill(
                                          label: 'Lng',
                                          value: candidate.point.longitude
                                              .toStringAsFixed(5),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: kLogisticsSilverIcon,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompanyLocationPickerDialog extends StatefulWidget {
  final String companyName;
  final List<LogisticsZoneRecord> zones;
  final LatLng? initialPoint;

  const _CompanyLocationPickerDialog({
    required this.companyName,
    required this.zones,
    required this.initialPoint,
  });

  @override
  State<_CompanyLocationPickerDialog> createState() =>
      _CompanyLocationPickerDialogState();
}

class _CompanyLocationPickerDialogState
    extends State<_CompanyLocationPickerDialog> {
  final MapController _mapController = MapController();
  LatLng? _selectedPoint;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialPoint;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  List<_RenderedZonePolygon> get _renderedZones {
    final polygons = <_RenderedZonePolygon>[];
    for (var i = 0; i < widget.zones.length; i++) {
      final points = _resolvedZonePolygonPointsForRecord(
        widget.zones[i],
        fallbackIndex: i,
      );
      if (points.length < 3) continue;
      final color = _zoneColorFromHex(widget.zones[i].colorHex);
      polygons.add(
        _RenderedZonePolygon(
          code: widget.zones[i].code,
          label: widget.zones[i].name,
          fillColor: color.withValues(alpha: 0.16),
          borderColor: color.withValues(alpha: 0.94),
          points: points,
          fallbackTemplate:
              _zonePolygonPointsFromRaw(widget.zones[i].polygonPoints).length <
              3,
        ),
      );
    }
    return polygons;
  }

  _ZoneDetectionResult? get _detection {
    final point = _selectedPoint;
    if (point == null) return null;
    return _detectZoneForCoordinate(point: point, zones: widget.zones);
  }

  void _handleMapReady() {
    _mapReady = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fitMap();
    });
  }

  void _fitMap() {
    if (!_mapReady) return;
    if (_selectedPoint != null) {
      _mapController.move(_selectedPoint!, 13.8);
      return;
    }
    final allPoints = <LatLng>[
      for (final zone in _renderedZones) ...zone.points,
    ];
    if (allPoints.length >= 2) {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: allPoints,
          padding: const EdgeInsets.all(44),
          maxZoom: 12.8,
        ),
      );
      return;
    }
    _mapController.move(const LatLng(20.5235, -100.8157), 10.9);
  }

  @override
  Widget build(BuildContext context) {
    final detection = _detection;
    final renderedZones = _renderedZones;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 720),
        child: _CatalogSurface(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 940;
              final mapCanvas = ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter:
                              _selectedPoint ??
                              const LatLng(20.5235, -100.8157),
                          initialZoom: _selectedPoint == null ? 10.9 : 13.8,
                          interactionOptions: const InteractionOptions(
                            flags:
                                InteractiveFlag.all &
                                ~InteractiveFlag.doubleTapZoom,
                          ),
                          onTap: (_, point) {
                            setState(() => _selectedPoint = point);
                          },
                          onMapReady: _handleMapReady,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.dicsa.operacion',
                          ),
                          if (renderedZones.isNotEmpty)
                            PolygonLayer(
                              polygons: renderedZones
                                  .map(
                                    (zone) => Polygon(
                                      points: zone.points,
                                      color: zone.fillColor,
                                      borderColor: zone.borderColor,
                                      borderStrokeWidth: 2,
                                      label: zone.code,
                                      labelStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: kLogisticsSilverTextPrimary,
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          if (_selectedPoint != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  width: 44,
                                  height: 44,
                                  point: _selectedPoint!,
                                  child: Container(
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: kLogisticsSilverTextPrimary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          blurRadius: 14,
                                          color: Colors.black.withValues(
                                            alpha: 0.18,
                                          ),
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.place_rounded,
                                      size: 22,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          RichAttributionWidget(
                            attributions: [
                              TextSourceAttribution(
                                'OpenStreetMap contributors',
                                onTap: () {
                                  unawaited(
                                    launchUrl(
                                      Uri.parse(
                                        'https://openstreetmap.org/copyright',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 320),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.86),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: kLogisticsSilverBorderLight,
                          ),
                        ),
                        child: const Text(
                          'Haz tap sobre el mapa para fijar la ubicación de la empresa y validar en qué zona cae.',
                          style: TextStyle(
                            fontSize: 12.2,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                            color: kLogisticsSilverTextSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );

              final side = Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: kLogisticsCapsuleGradient,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kLogisticsSilverBorderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.companyName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: kLogisticsSilverTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_selectedPoint == null)
                      const Text(
                        'Todavía no hay una ubicación marcada.',
                        style: TextStyle(
                          fontSize: 12.4,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                          color: kLogisticsSilverTextSecondary,
                        ),
                      )
                    else ...[
                      _CompactMetricPill(
                        label: 'Lat',
                        value: _selectedPoint!.latitude.toStringAsFixed(5),
                      ),
                      const SizedBox(height: 8),
                      _CompactMetricPill(
                        label: 'Lng',
                        value: _selectedPoint!.longitude.toStringAsFixed(5),
                      ),
                      const SizedBox(height: 12),
                      if (detection?.hasSingleMatch == true)
                        Text(
                          'Zona detectada: ${detection!.singleMatch!.code} · ${detection.singleMatch!.name}',
                          style: const TextStyle(
                            fontSize: 12.6,
                            height: 1.4,
                            fontWeight: FontWeight.w800,
                            color: kLogisticsSilverTextPrimary,
                          ),
                        )
                      else if (detection?.hasMultipleMatches == true)
                        Text(
                          'La ubicación cae en varias zonas: ${detection!.matches.map((zone) => zone.code).join(', ')}.',
                          style: const TextStyle(
                            fontSize: 12.4,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8A5A3F),
                          ),
                        )
                      else
                        const Text(
                          'La ubicación todavía no cae dentro de ninguna zona activa.',
                          style: TextStyle(
                            fontSize: 12.4,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8A5A3F),
                          ),
                        ),
                    ],
                    const Spacer(),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _fitMap,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kLogisticsSilverTextPrimary,
                            side: const BorderSide(
                              color: kLogisticsSilverBorder,
                            ),
                          ),
                          icon: const Icon(Icons.center_focus_strong_rounded),
                          label: const Text('Encuadrar'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _selectedPoint == null
                              ? null
                              : () => setState(() => _selectedPoint = null),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kLogisticsSilverTextPrimary,
                            side: const BorderSide(
                              color: kLogisticsSilverBorder,
                            ),
                          ),
                          icon: const Icon(Icons.delete_sweep_rounded),
                          label: const Text('Quitar punto'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: _selectedPoint == null
                              ? null
                              : () => Navigator.of(context).pop(_selectedPoint),
                          style: FilledButton.styleFrom(
                            backgroundColor: kLogisticsSilverTextPrimary,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Usar ubicación'),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              if (compact) {
                return Column(
                  children: [
                    Expanded(flex: 6, child: mapCanvas),
                    const SizedBox(height: 12),
                    Expanded(flex: 4, child: side),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 9, child: mapCanvas),
                  const SizedBox(width: 14),
                  SizedBox(width: 320, child: side),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LogisticsZoneEditorDialog extends StatefulWidget {
  final LogisticsZoneRecord? record;

  const _LogisticsZoneEditorDialog({this.record});

  @override
  State<_LogisticsZoneEditorDialog> createState() =>
      _LogisticsZoneEditorDialogState();
}

class _LogisticsZoneEditorDialogState
    extends State<_LogisticsZoneEditorDialog> {
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _colorController;
  late final TextEditingController _coverageController;
  late final TextEditingController _orderController;
  late final TextEditingController _notesController;

  late bool _active;
  late String _polygonTemplateKey;
  late List<LatLng> _draftPolygonPoints;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _codeController = TextEditingController(text: record?.code ?? '');
    _nameController = TextEditingController(text: record?.name ?? '');
    _colorController = TextEditingController(
      text: record?.colorHex ?? '#C7CDD4',
    );
    _coverageController = TextEditingController(
      text: record?.coverageHint ?? '',
    );
    _orderController = TextEditingController(
      text: (record?.displayOrder ?? 0).toString(),
    );
    _notesController = TextEditingController(text: record?.notes ?? '');
    _active = record?.active ?? true;
    _draftPolygonPoints = _zonePolygonPointsFromRaw(
      record?.polygonPoints ?? const [],
    );
    _polygonTemplateKey = _inferZonePolygonTemplateKey(record);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _colorController.dispose();
    _coverageController.dispose();
    _orderController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label, {String? helperText}) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.70),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kLogisticsSilverBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kLogisticsSilverBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: kLogisticsSilverTextPrimary,
          width: 1.2,
        ),
      ),
    );
  }

  Color _previewZoneColor() {
    final normalized = normalizeLogisticsZoneColorHex(_colorController.text);
    return Color(int.parse(normalized.substring(1), radix: 16) + 0xFF000000);
  }

  List<LatLng> _resolvedPolygonPreviewPoints() {
    switch (_polygonTemplateKey) {
      case _kZonePolygonTemplateNone:
        return const <LatLng>[];
      case _kZonePolygonTemplateExisting:
        return _draftPolygonPoints;
      default:
        final template = _zonePolygonTemplateByKey(_polygonTemplateKey);
        return template?.points ?? _draftPolygonPoints;
    }
  }

  String _polygonPreviewLabel() {
    final points = _resolvedPolygonPreviewPoints();
    if (points.isEmpty) return 'Sin polígono';
    if (_polygonTemplateKey == _kZonePolygonTemplateExisting) {
      return '${points.length} vértices manuales';
    }
    final template = _zonePolygonTemplateByKey(_polygonTemplateKey);
    if (template != null) {
      return '${template.label} · ${points.length} vértices';
    }
    return '${points.length} vértices';
  }

  Future<void> _openPolygonEditor() async {
    final zoneName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : (_codeController.text.trim().isNotEmpty
              ? _codeController.text.trim()
              : 'Zona logística');
    final edited = await showDialog<List<Map<String, double>>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ZonePolygonMapEditorDialog(
        zoneName: zoneName,
        initialPoints: _resolvedPolygonPreviewPoints(),
        previewColor: _previewZoneColor(),
      ),
    );
    if (edited == null) return;

    final parsed = _zonePolygonPointsFromRaw(edited);
    setState(() {
      _draftPolygonPoints = parsed;
      _polygonTemplateKey = parsed.isEmpty
          ? _kZonePolygonTemplateNone
          : _kZonePolygonTemplateExisting;
    });
  }

  void _submit() {
    final code = normalizeLogisticsZoneCode(_codeController.text);
    final name = _nameController.text.trim();
    if (code.isEmpty || name.isEmpty) {
      setState(() {
        _validationMessage =
            'La zona necesita al menos una clave y un nombre homologado.';
      });
      return;
    }

    final resolvedRecord = LogisticsZoneRecord(
      id: widget.record?.id ?? buildLogisticsZoneId(code: code, name: name),
      code: code,
      name: name,
      city: widget.record?.city ?? 'Celaya',
      state: widget.record?.state ?? 'Guanajuato',
      colorHex: normalizeLogisticsZoneColorHex(_colorController.text),
      coverageHint: _coverageController.text.trim(),
      displayOrder: int.tryParse(_orderController.text.trim()) ?? 0,
      polygonPoints: switch (_polygonTemplateKey) {
        _kZonePolygonTemplateNone => const [],
        _kZonePolygonTemplateExisting => _zonePolygonPointsToJson(
          _draftPolygonPoints,
        ),
        _ => _zonePolygonPointsToJson(
          _zonePolygonTemplateByKey(_polygonTemplateKey)?.points ?? const [],
        ),
      },
      active: _active,
      notes: _notesController.text.trim(),
      updatedAt: widget.record?.updatedAt,
    );

    Navigator.of(context).pop(resolvedRecord);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: _CatalogSurface(
          padding: const EdgeInsets.all(18),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.record == null
                      ? 'Nueva zona logística'
                      : 'Editar zona ${widget.record!.name}',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: kLogisticsSilverTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'La zona ya puede nacer con polígono base para que el mapa y la asignación visual no dependan de cuadrantes genéricos.',
                  style: TextStyle(
                    fontSize: 12.6,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: kLogisticsSilverTextSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _codeController,
                        decoration: _decoration(
                          'Clave',
                          helperText: 'Ejemplo: CEL-NORTE',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 360,
                      child: TextField(
                        controller: _nameController,
                        decoration: _decoration('Nombre de zona'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 180,
                      child: TextField(
                        controller: _colorController,
                        decoration: _decoration(
                          'Color visual',
                          helperText: 'Hexadecimal, ejemplo #C7CDD4',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: TextField(
                        controller: _orderController,
                        keyboardType: TextInputType.number,
                        decoration: _decoration('Orden en pantalla'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _polygonTemplateKey,
                  decoration: _decoration(
                    'Polígono base',
                    helperText:
                        'Sirve para que la zona se pinte de inmediato dentro del mapa.',
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: _kZonePolygonTemplateNone,
                      child: Text('Sin polígono todavía'),
                    ),
                    if (widget.record != null &&
                        _polygonTemplateKey == _kZonePolygonTemplateExisting)
                      const DropdownMenuItem<String>(
                        value: _kZonePolygonTemplateExisting,
                        child: Text('Conservar polígono existente'),
                      ),
                    ..._logisticsZonePolygonTemplates().map(
                      (template) => DropdownMenuItem<String>(
                        value: template.key,
                        child: Text('${template.code} · ${template.label}'),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _polygonTemplateKey = value);
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.74),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: kLogisticsSilverBorderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _CompactMetricPill(
                            label: 'Estado',
                            value: _polygonPreviewLabel(),
                          ),
                          _CompactMetricPill(
                            label: 'Puntos',
                            value: _resolvedPolygonPreviewPoints().length
                                .toString(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Aquí ya puedes brincar del esquema base al polígono real dibujado en mapa.',
                        style: TextStyle(
                          fontSize: 12.2,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: kLogisticsSilverTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => unawaited(_openPolygonEditor()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kLogisticsSilverTextPrimary,
                            side: const BorderSide(
                              color: kLogisticsSilverBorder,
                            ),
                          ),
                          icon: const Icon(Icons.gesture_rounded, size: 18),
                          label: const Text('Dibujar/editar polígono'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _coverageController,
                  maxLines: 2,
                  decoration: _decoration(
                    'Cobertura o perímetro',
                    helperText:
                        'Colonias, parques industriales o referencia territorial.',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  maxLines: 4,
                  decoration: _decoration(
                    'Notas',
                    helperText:
                        'Capacidad operativa, tráfico, restricciones o contexto.',
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  value: _active,
                  onChanged: (value) {
                    setState(() => _active = value);
                  },
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: kLogisticsSilverTextPrimary,
                  title: const Text(
                    'Zona activa',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: kLogisticsSilverTextPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'Mantén activas solo las zonas que sí deben usarse para planeación.',
                    style: TextStyle(
                      fontSize: 12.2,
                      fontWeight: FontWeight.w600,
                      color: kLogisticsSilverTextSecondary,
                    ),
                  ),
                ),
                if (_validationMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _validationMessage!,
                    style: const TextStyle(
                      fontSize: 12.4,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8A3F3F),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: kLogisticsSilverTextPrimary,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.save_outlined),
                      label: Text(
                        widget.record == null ? 'Crear zona' : 'Guardar zona',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ZonePolygonMapEditorDialog extends StatefulWidget {
  final String zoneName;
  final List<LatLng> initialPoints;
  final Color previewColor;

  const _ZonePolygonMapEditorDialog({
    required this.zoneName,
    required this.initialPoints,
    required this.previewColor,
  });

  @override
  State<_ZonePolygonMapEditorDialog> createState() =>
      _ZonePolygonMapEditorDialogState();
}

class _ZonePolygonMapEditorDialogState
    extends State<_ZonePolygonMapEditorDialog> {
  final MapController _mapController = MapController();
  late List<LatLng> _points;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _points = List<LatLng>.from(widget.initialPoints);
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  bool get _canSave => _points.isEmpty || _points.length >= 3;

  void _handleMapReady() {
    _mapReady = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fitToPoints();
    });
  }

  void _fitToPoints() {
    if (!_mapReady) return;
    if (_points.isEmpty) {
      _mapController.move(const LatLng(20.5235, -100.8157), 10.9);
      return;
    }
    if (_points.length == 1) {
      _mapController.move(_points.first, 14.2);
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: _points,
        padding: const EdgeInsets.all(48),
        maxZoom: 14.5,
      ),
    );
  }

  void _addPoint(LatLng point) {
    setState(() => _points = [..._points, point]);
  }

  void _removePointAt(int index) {
    if (index < 0 || index >= _points.length) return;
    setState(() {
      _points = [..._points]..removeAt(index);
    });
  }

  void _undoLastPoint() {
    if (_points.isEmpty) return;
    setState(() {
      _points = [..._points]..removeLast();
    });
  }

  void _clearPoints() {
    setState(() => _points = const <LatLng>[]);
  }

  void _save() {
    if (!_canSave) return;
    Navigator.of(context).pop(_zonePolygonPointsToJson(_points));
  }

  @override
  Widget build(BuildContext context) {
    final polygonFill = widget.previewColor.withValues(alpha: 0.18);
    final polygonStroke = widget.previewColor.withValues(alpha: 0.94);

    Widget buildVertexRow(int index) {
      final point = _points[index];
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kLogisticsSilverBorderLight),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: polygonStroke,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
                style: const TextStyle(
                  fontSize: 11.8,
                  fontWeight: FontWeight.w700,
                  color: kLogisticsSilverTextSecondary,
                ),
              ),
            ),
            IconButton(
              onPressed: () => _removePointAt(index),
              tooltip: 'Quitar vértice',
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: kLogisticsSilverIcon,
              ),
            ),
          ],
        ),
      );
    }

    final mapCanvas = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _points.isNotEmpty
                    ? _points.first
                    : const LatLng(20.5235, -100.8157),
                initialZoom: _points.isNotEmpty ? 13.2 : 10.9,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.doubleTapZoom,
                ),
                onTap: (_, point) => _addPoint(point),
                onMapReady: _handleMapReady,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.dicsa.operacion',
                ),
                if (_points.length >= 3)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: _points,
                        color: polygonFill,
                        borderColor: polygonStroke,
                        borderStrokeWidth: 2.4,
                      ),
                    ],
                  ),
                if (_points.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _points,
                        strokeWidth: 3.2,
                        color: polygonStroke,
                        borderStrokeWidth: 1.0,
                        borderColor: Colors.white.withValues(alpha: 0.82),
                      ),
                    ],
                  ),
                if (_points.isNotEmpty)
                  MarkerLayer(
                    markers: [
                      for (var i = 0; i < _points.length; i++)
                        Marker(
                          width: 34,
                          height: 34,
                          point: _points[i],
                          child: GestureDetector(
                            onTap: () => _removePointAt(i),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: polygonStroke,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.94),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 10,
                                    color: Colors.black.withValues(alpha: 0.14),
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () {
                        unawaited(
                          launchUrl(
                            Uri.parse('https://openstreetmap.org/copyright'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.84),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kLogisticsSilverBorderLight),
              ),
              child: const Text(
                'Haz tap en el mapa para agregar vértices. Toca un punto numerado para quitarlo.',
                style: TextStyle(
                  fontSize: 12.2,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  color: kLogisticsSilverTextSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final sidePanel = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: kLogisticsCapsuleGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kLogisticsSilverBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.zoneName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: kLogisticsSilverTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CompactMetricPill(
                label: 'Vértices',
                value: _points.length.toString(),
              ),
              _CompactMetricPill(
                label: 'Estado',
                value: _points.isEmpty
                    ? 'Vacío'
                    : (_points.length >= 3 ? 'Listo' : 'Incompleto'),
              ),
            ],
          ),
          if (!_canSave) ...[
            const SizedBox(height: 10),
            const Text(
              'Se ocupan al menos 3 vértices para cerrar un polígono.',
              style: TextStyle(
                fontSize: 11.8,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8A5A3F),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _fitToPoints,
                style: OutlinedButton.styleFrom(
                  foregroundColor: kLogisticsSilverTextPrimary,
                  side: const BorderSide(color: kLogisticsSilverBorder),
                ),
                icon: const Icon(Icons.center_focus_strong_rounded, size: 18),
                label: const Text('Encuadrar'),
              ),
              OutlinedButton.icon(
                onPressed: _points.isEmpty ? null : _undoLastPoint,
                style: OutlinedButton.styleFrom(
                  foregroundColor: kLogisticsSilverTextPrimary,
                  side: const BorderSide(color: kLogisticsSilverBorder),
                ),
                icon: const Icon(Icons.undo_rounded, size: 18),
                label: const Text('Deshacer'),
              ),
              OutlinedButton.icon(
                onPressed: _points.isEmpty ? null : _clearPoints,
                style: OutlinedButton.styleFrom(
                  foregroundColor: kLogisticsSilverTextPrimary,
                  side: const BorderSide(color: kLogisticsSilverBorder),
                ),
                icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                label: const Text('Limpiar'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _points.isEmpty
                ? const Center(
                    child: Text(
                      'Todavía no hay vértices.\nEmpieza tocando el mapa.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.4,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: kLogisticsSilverTextSecondary,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _points.length,
                    itemBuilder: (context, index) => buildVertexRow(index),
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _canSave ? _save : null,
                style: FilledButton.styleFrom(
                  backgroundColor: kLogisticsSilverTextPrimary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Usar polígono'),
              ),
            ],
          ),
        ],
      ),
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 760),
        child: _CatalogSurface(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 980;
              if (compact) {
                return SizedBox(
                  height: 680,
                  child: Column(
                    children: [
                      Expanded(flex: 6, child: mapCanvas),
                      const SizedBox(height: 12),
                      Expanded(flex: 5, child: sidePanel),
                    ],
                  ),
                );
              }

              return SizedBox(
                height: 680,
                child: Row(
                  children: [
                    Expanded(flex: 9, child: mapCanvas),
                    const SizedBox(width: 14),
                    SizedBox(width: 340, child: sidePanel),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CatalogEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _CatalogEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return _CatalogSurface(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: kLogisticsSilverIcon),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: kLogisticsSilverTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.8,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: kLogisticsSilverTextSecondary,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: kLogisticsSilverIcon,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogBlueprintCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> lines;

  const _CatalogBlueprintCard({
    required this.icon,
    required this.title,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: _CatalogSurface(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: kLogisticsCapsuleGradient,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kLogisticsSilverBorderLight),
                  ),
                  child: Icon(icon, size: 18, color: kLogisticsSilverIcon),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: kLogisticsSilverTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Icon(
                        Icons.circle,
                        size: 7,
                        color: kLogisticsSilverIcon,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        line,
                        style: const TextStyle(
                          fontSize: 12.2,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: kLogisticsSilverTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
