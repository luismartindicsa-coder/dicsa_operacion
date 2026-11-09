import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/utils/fetch_all_supabase_rows.dart';

DateTime? _date(dynamic value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toUtc();
String gpsVisitDate(DateTime? value) {
  if (value == null) return 'Sin registro';
  final d = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

class LogisticsGpsVisit {
  final String? vehicleId, siteId;
  final String id,
      unitId,
      unitLabel,
      placeLabel,
      geofenceName,
      classification,
      status,
      arrivalKind;
  final DateTime startedAt, lastInsideAt;
  final DateTime? endedAt;
  final bool hasGap;
  final int minimumDwellSeconds;
  LogisticsGpsVisit.fromRow(Map<String, dynamic> r)
    : vehicleId = r['vehicle_id']?.toString(),
      siteId = r['site_id']?.toString(),
      id = r['id'].toString(),
      unitId = r['provider_unit_id'].toString(),
      unitLabel = r['unit_label'].toString(),
      placeLabel = r['place_label'].toString(),
      geofenceName = r['geofence_name'].toString(),
      classification = r['classification'].toString(),
      status = r['status'].toString(),
      arrivalKind = r['arrival_kind'].toString(),
      startedAt = _date(r['started_at'])!,
      lastInsideAt = _date(r['last_inside_at'])!,
      endedAt = _date(r['ended_at']),
      hasGap = r['has_gap'] == true,
      minimumDwellSeconds = (r['minimum_dwell_seconds'] as num?)?.toInt() ?? 60;
  bool get visibleInVisitLog =>
      !isDicsaCelaya(placeLabel) &&
      !isDicsaCelaya(geofenceName) &&
      (endedAt ?? lastInsideAt).difference(startedAt) >=
          const Duration(minutes: 5);
  String get arrivalLabel =>
      arrivalKind == 'arrival' ? 'Llegada aproximada' : 'Detectada dentro';
  String get statusLabel => switch (status) {
    'closed' => 'Salida registrada',
    'interrupted' => 'Seguimiento interrumpido',
    _ => 'Visita abierta',
  };
  // A timer never advances on a stale fix. Gaps do not become fabricated dwell.
  String get durationLabel {
    if (hasGap || status == 'interrupted') {
      return 'No determinable por interrupción';
    }
    final elapsed = (endedAt ?? lastInsideAt).difference(startedAt);
    final minutes = elapsed.inMinutes;
    final text = minutes < 60
        ? '$minutes min'
        : '${minutes ~/ 60} h ${minutes % 60} min';
    return '${arrivalKind == 'first_seen' || status == 'open' ? 'Al menos ' : 'Aprox. '}$text';
  }
}

bool isDicsaCelaya(String label) =>
    RegExp(r'\bdicsa[\s·_-]+celaya\b', caseSensitive: false).hasMatch(label);

class LogisticsGpsVisitBundle {
  final List<LogisticsGpsVisit> visits;
  final List<Map<String, dynamic>> presence;
  final String status;
  final DateTime? lastRunAt, enabledAt;
  const LogisticsGpsVisitBundle({
    this.visits = const [],
    this.presence = const [],
    this.status = 'pending',
    this.lastRunAt,
    this.enabledAt,
  });
  bool isLive(DateTime now) =>
      status == 'ok' &&
      lastRunAt != null &&
      now.difference(lastRunAt!) <= const Duration(minutes: 3);
  String? notice(DateTime now) {
    if (status == 'pending') {
      return 'La bitácora está esperando sus primeras posiciones.';
    }
    if (!isLive(now)) {
      return 'Detección de visitas en pausa. Se conserva la bitácora; no se infieren llegadas ni salidas.';
    }
    return null;
  }

  String location(String unitId, DateTime now, {required bool sourceFresh}) {
    if (!sourceFresh) {
      return 'Lugar sin confirmar con los datos actuales';
    }
    if (!isLive(now)) {
      return 'Lugar sin confirmar: detección en pausa';
    }
    final states = presence
        .where((s) => s['provider_unit_id'] == unitId)
        .toList();
    if (states.isEmpty) return 'Lugar por confirmar';
    final reliable = states.where((s) {
      final t = _date(s['last_position_at']);
      return t != null &&
          !t.isAfter(now) &&
          now.difference(t) <= const Duration(minutes: 15) &&
          s['continuity_lost'] != true;
    }).toList();
    if (reliable.length != states.length) {
      return 'Lugar sin confirmar: faltan posiciones recientes';
    }
    final inside = reliable.where((s) => s['mode'] == 'inside').toList();
    final places = <String>[];
    for (final s in inside) {
      final visit = visits
          .where((v) => v.id == s['active_visit_id'] && v.status == 'open')
          .firstOrNull;
      if (visit != null) {
        places.add(
          '${visit.placeLabel}${s['candidate_mode'] == 'outside' ? ' · salida por confirmar' : ''}',
        );
      }
    }
    if (places.isNotEmpty) return 'En ${places.join(' / ')}';
    if (reliable.every(
      (s) => s['mode'] == 'outside' && s['candidate_mode'] == null,
    )) {
      return 'Fuera de empresas y bases vinculadas';
    }
    return 'Lugar por confirmar';
  }
}

class LogisticsGpsVisitStore {
  static Future<LogisticsGpsVisitBundle> load() async {
    final c = Supabase.instance.client;
    final since = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 30))
        .toIso8601String();
    final results = await Future.wait([
      fetchAllSupabaseRows(
        (from, to) => c
            .from('logistics_gps_visits')
            .select()
            .or('status.eq.open,started_at.gte.$since')
            .order('started_at', ascending: false)
            .order('unit_label')
            .order('id')
            .range(from, to),
      ),
      fetchAllSupabaseRows(
        (from, to) => c
            .from('logistics_gps_presence')
            .select(
              'provider_unit_id,resource_id,geofence_id,mode,last_position_at,candidate_mode,active_visit_id,continuity_lost',
            )
            .order('provider_unit_id')
            .order('resource_id')
            .order('geofence_id')
            .range(from, to),
      ),
      c
          .from('logistics_gps_visit_monitor')
          .select('status,last_run_at,enabled_at')
          .eq('singleton', true),
    ]);
    if (results[2].isEmpty) {
      throw const PostgrestException(
        message: 'Visit access unavailable',
        code: '42501',
      );
    }
    final monitor = results[2].single;
    return LogisticsGpsVisitBundle(
      visits: results[0].map(LogisticsGpsVisit.fromRow).toList(),
      presence: results[1],
      status: monitor['status'].toString(),
      lastRunAt: _date(monitor['last_run_at']),
      enabledAt: _date(monitor['enabled_at']),
    );
  }
}
