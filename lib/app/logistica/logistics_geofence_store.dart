import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/utils/fetch_all_supabase_rows.dart';

const logisticsGeofenceKinds = <String, String>{
  'pending': 'Pendiente de vincular',
  'company': 'Empresa',
  'base': 'Base DICSA',
  'other': 'Otro lugar',
  'ignored': 'Oculta del mapa',
};

class LogisticsGeofence {
  final String resourceId, id, name, classification;
  final String? siteId, siteName;
  final bool visible, siteActive;
  final int shapeType, linkVersion;
  final double widthMeters;
  final List<LatLng> points;
  const LogisticsGeofence({
    required this.resourceId,
    required this.id,
    required this.name,
    required this.classification,
    required this.visible,
    required this.shapeType,
    required this.widthMeters,
    required this.points,
    required this.linkVersion,
    this.siteId,
    this.siteName,
    this.siteActive = false,
  });
  factory LogisticsGeofence.fromRow(Map<String, dynamic> row) {
    final site = row['sites'] as Map?;
    return LogisticsGeofence(
      resourceId: row['resource_id'].toString(),
      id: row['geofence_id'].toString(),
      name: row['provider_name'].toString(),
      classification: row['classification'].toString(),
      visible: row['provider_visible'] == true,
      shapeType: (row['shape_type'] as num).toInt(),
      widthMeters: (row['width_m'] as num).toDouble(),
      points: (row['points'] as List? ?? [])
          .map(
            (p) => LatLng(
              (p['lat'] as num).toDouble(),
              (p['lng'] as num).toDouble(),
            ),
          )
          .toList(),
      linkVersion: (row['link_version'] as num).toInt(),
      siteId: row['site_id']?.toString(),
      siteName: site?['name']?.toString(),
      siteActive: site?['is_active'] == true,
    );
  }
  String get key => '$resourceId/$id';
  bool get needsReview =>
      classification == 'pending' ||
      (classification == 'company' && (siteId == null || !siteActive));
  bool get hasGeometry => visible && points.isNotEmpty;
  bool get showOnMap => hasGeometry && classification != 'ignored';
  String get linkLabel => classification == 'company'
      ? (siteName == null
            ? 'Empresa no disponible'
            : '$siteName${siteActive ? '' : ' · inactiva'}')
      : logisticsGeofenceKinds[classification] ?? 'Pendiente de vincular';
  String get shapeLabel => switch (shapeType) {
    1 => 'Corredor',
    2 => 'Polígono',
    _ => 'Círculo · radio ${widthMeters.toStringAsFixed(0)} m',
  };
  List<LatLng> get fitPoints => shapeType == 3 && points.isNotEmpty
      ? [
          for (final angle in [0.0, 90.0, 180.0, 270.0])
            const Distance().offset(points.first, widthMeters, angle),
        ]
      : points;
}

class LogisticsGeofenceBundle {
  final List<LogisticsGeofence> fences;
  final String state;
  final String? errorCode;
  final DateTime? lastSuccessAt;
  const LogisticsGeofenceBundle({
    this.fences = const [],
    this.state = 'pending',
    this.errorCode,
    this.lastSuccessAt,
  });
  String? notice(DateTime now) {
    if (state == 'pending') {
      return 'Geocercas pendientes de consultar en EPCOM.';
    }
    if (errorCode == 'authorization') {
      return 'EPCOM no autorizó la consulta de geocercas.';
    }
    if (state == 'error' ||
        lastSuccessAt == null ||
        now.difference(lastSuccessAt!) > const Duration(minutes: 25)) {
      return 'Geocercas sin actualizar. Se conserva la última consulta recibida.';
    }
    return null;
  }
}

class LogisticsGeofenceStore {
  static Future<LogisticsGeofenceBundle> load() async {
    final client = Supabase.instance.client;
    final results = await Future.wait([
      fetchAllSupabaseRows(
        (from, to) => client
            .from('logistics_geofences')
            .select(
              'resource_id,geofence_id,provider_name,shape_type,width_m,points,provider_visible,site_id,classification,link_version,sites(name,is_active)',
            )
            .order('resource_id')
            .order('geofence_id')
            .range(from, to),
      ),
      client
          .from('logistics_geofence_sync_state')
          .select('status,last_success_at,error_code')
          .eq('singleton', true),
    ]);
    final rows = results[1];
    if (rows.isEmpty) {
      throw const PostgrestException(
        message: 'Geofence access unavailable',
        code: '42501',
      );
    }
    return LogisticsGeofenceBundle(
      fences: results[0].map(LogisticsGeofence.fromRow).toList()
        ..sort((a, b) => a.name.toUpperCase().compareTo(b.name.toUpperCase())),
      state: rows.single['status'].toString(),
      errorCode: rows.single['error_code']?.toString(),
      lastSuccessAt: DateTime.tryParse(
        rows.single['last_success_at']?.toString() ?? '',
      )?.toUtc(),
    );
  }

  static Future<List<Map<String, dynamic>>> companies() => fetchAllSupabaseRows(
    (from, to) => Supabase.instance.client
        .from('sites')
        .select('id,name')
        .eq('type', 'cliente')
        .eq('is_active', true)
        .order('name')
        .range(from, to),
  );
  static Future<void> saveLink(
    LogisticsGeofence fence,
    String kind,
    String? siteId,
  ) async {
    await Supabase.instance.client.rpc(
      'link_logistics_geofence',
      params: {
        'p_resource_id': fence.resourceId,
        'p_geofence_id': fence.id,
        'p_site_id': siteId,
        'p_classification': kind,
        'p_expected_version': fence.linkVersion,
      },
    );
  }
}
