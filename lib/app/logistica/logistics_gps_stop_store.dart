import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/utils/fetch_all_supabase_rows.dart';

DateTime? _date(dynamic value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toUtc();

class LogisticsGpsStop {
  final String id, unitId, unitLabel, status;
  final String? endReason, reviewNote;
  final double latitude, longitude;
  final DateTime startedAt, lastStationaryAt;
  final DateTime? endedAt, reviewedAt;
  final int reviewVersion;
  LogisticsGpsStop.fromRow(Map<String, dynamic> r)
    : id = r['id'].toString(),
      unitId = r['provider_unit_id'].toString(),
      unitLabel = r['unit_label'].toString(),
      status = r['status'].toString(),
      latitude = (r['latitude'] as num).toDouble(),
      longitude = (r['longitude'] as num).toDouble(),
      startedAt = _date(r['started_at'])!,
      lastStationaryAt = _date(r['last_stationary_at'])!,
      endedAt = _date(r['ended_at']),
      reviewedAt = _date(r['reviewed_at']),
      endReason = r['end_reason']?.toString(),
      reviewNote = r['review_note']?.toString(),
      reviewVersion = (r['review_version'] as num?)?.toInt() ?? 0;
  String get coordinates =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  bool get reviewed => reviewedAt != null;
  String get statusLabel => switch (status) {
    'closed' => 'Parada finalizada',
    'interrupted' => 'Seguimiento interrumpido',
    _ => 'Parada abierta',
  };
  String get durationLabel {
    final minutes = lastStationaryAt.difference(startedAt).inMinutes;
    return 'Al menos ${minutes < 60 ? '$minutes min' : '${minutes ~/ 60} h ${minutes % 60} min'} observados';
  }

  String get endLabel => switch (endReason) {
    'movement' => 'Movimiento detectado',
    'geofence_entered' => 'Posición en una geocerca o su borde',
    'geofences_changed' => 'Cambiaron las geocercas',
    'unit_unavailable' => 'Unidad no disponible',
    'speed_unavailable' => 'Velocidad no disponible',
    'signal_gap' || 'position_unavailable' => 'Faltan posiciones recientes',
    'source_unavailable' => 'Consulta de GPS o geocercas interrumpida',
    _ => 'Sin fin confirmado',
  };
}

class LogisticsGpsStopBundle {
  final List<LogisticsGpsStop> stops;
  final String status;
  final DateTime? enabledAt, lastRunAt;
  const LogisticsGpsStopBundle({
    this.stops = const [],
    this.status = 'pending',
    this.enabledAt,
    this.lastRunAt,
  });
  bool isLive(DateTime now) =>
      status == 'ok' &&
      lastRunAt != null &&
      now.difference(lastRunAt!) <= const Duration(minutes: 3);
  String? notice(DateTime now) => status == 'pending'
      ? 'Las paradas sin geocerca se registrarán al recibir nuevas posiciones.'
      : isLive(now)
      ? null
      : 'Detección de paradas en pausa. Se conserva la última información.';
}

class LogisticsGpsStopStore {
  static Future<LogisticsGpsStopBundle> load() async {
    final c = Supabase.instance.client;
    final since = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 30))
        .toIso8601String();
    final results = await Future.wait([
      fetchAllSupabaseRows(
        (from, to) => c
            .from('logistics_gps_stops')
            .select()
            .or('status.eq.open,started_at.gte.$since')
            .order('started_at', ascending: false)
            .order('unit_label')
            .order('id')
            .range(from, to),
      ),
      c
          .from('logistics_gps_stop_monitor')
          .select('status,last_run_at,enabled_at')
          .eq('singleton', true),
    ]);
    if (results[1].isEmpty) {
      throw const PostgrestException(
        message: 'Stop access unavailable',
        code: '42501',
      );
    }
    final monitor = results[1].single;
    return LogisticsGpsStopBundle(
      stops: results[0].map(LogisticsGpsStop.fromRow).toList(),
      status: monitor['status'].toString(),
      enabledAt: _date(monitor['enabled_at']),
      lastRunAt: _date(monitor['last_run_at']),
    );
  }

  static Future<void> review(LogisticsGpsStop stop, String note) async {
    if (note.trim().isEmpty || note.length > 1000) {
      throw const FormatException(
        'Escribe un motivo o nota de hasta 1000 caracteres.',
      );
    }
    await Supabase.instance.client.rpc(
      'review_logistics_gps_stop',
      params: {
        'p_id': stop.id,
        'p_note': note.trim(),
        'p_expected_version': stop.reviewVersion,
      },
    );
  }
}
