import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/utils/fetch_all_supabase_rows.dart';
import 'logistics_gps_visit_store.dart';

// Celaya operational dates use UTC-6, independently of the device timezone.
DateTime gpsOperationalDay(DateTime instant) {
  final local = instant.toUtc().subtract(const Duration(hours: 6));
  return DateTime.utc(local.year, local.month, local.day);
}

String gpsDayKey(DateTime day) => day.toIso8601String().split('T').first;

class GpsDailyService {
  final String direction, notes, scheduledTime;
  final String id, company, unit, status;
  final String? vehicleId, siteId;
  final DateTime day;
  GpsDailyService.fromRow(
    Map<String, dynamic> row,
    Map<String, String> sites,
    Map<String, String> vehicles,
  ) : direction = row['direction']?.toString() ?? '',
      notes = row['notes']?.toString() ?? '',
      scheduledTime = row['scheduled_time']?.toString() ?? '',
      id = row['id'].toString(),
      vehicleId = row['vehicle_id']?.toString(),
      siteId = row['client_id']?.toString(),
      company =
          sites[row['client_id']] ??
          row['client_name']?.toString() ??
          'Sin empresa',
      unit = vehicles[row['vehicle_id']] ?? 'Sin unidad vinculada',
      status = row['status']?.toString() ?? 'Sin estado',
      day = DateTime.parse(
        (row['due_date'] ?? row['service_date']).toString().split('T').first,
      );
}

bool gpsVisitOnDay(LogisticsGpsVisit visit, DateTime day) {
  final start = DateTime.utc(day.year, day.month, day.day, 6);
  return visit.startedAt.isBefore(start.add(const Duration(days: 1))) &&
      !(visit.endedAt ?? visit.lastInsideAt).isBefore(start);
}

bool gpsVisitFitsService(GpsDailyService service, LogisticsGpsVisit visit) =>
    service.status != 'cancelado' &&
    !isDicsaCelaya(service.company) &&
    service.vehicleId != null &&
    service.siteId != null &&
    service.vehicleId == visit.vehicleId &&
    service.siteId == visit.siteId &&
    visit.visibleInVisitLog &&
    gpsVisitOnDay(visit, service.day);

enum GpsMatchKind { matched, noVisit, noService, review }

extension GpsMatchKindLabel on GpsMatchKind {
  String get label => switch (this) {
    GpsMatchKind.matched => 'Con visita coincidente',
    GpsMatchKind.noVisit => 'Sin visita encontrada',
    GpsMatchKind.noService => 'Sin servicio registrado',
    GpsMatchKind.review => 'Por revisar',
  };
}

class GpsDailyMatch {
  final GpsDailyService? service;
  final List<LogisticsGpsVisit> visits;
  final GpsMatchKind kind;
  final String reason;
  const GpsDailyMatch(this.service, this.visits, this.kind, this.reason);
  String get id =>
      service == null ? 'visit-${visits.single.id}' : 'service-${service!.id}';
  String get unit => service?.unit ?? visits.single.unitLabel;
  String get company => service?.company ?? visits.single.placeLabel;
}

List<GpsDailyMatch> reconcileGpsDay({
  required DateTime day,
  required List<GpsDailyService> services,
  required List<LogisticsGpsVisit> visits,
}) {
  final start = DateTime.utc(day.year, day.month, day.day, 6);
  final end = start.add(const Duration(days: 1));
  final eligible = visits
      .where(
        (v) =>
            v.visibleInVisitLog &&
            v.startedAt.isBefore(end) &&
            !(v.endedAt ?? v.lastInsideAt).isBefore(start),
      )
      .toList();
  final daily = services
      .where(
        (s) =>
            gpsDayKey(s.day) == gpsDayKey(day) &&
            s.status != 'cancelado' &&
            !isDicsaCelaya(s.company),
      )
      .toList();
  final candidates = <String, List<LogisticsGpsVisit>>{};
  final uses = <String, int>{};
  bool overlapsAnotherPlace(LogisticsGpsVisit visit) => eligible.any(
    (other) =>
        other.id != visit.id &&
        other.vehicleId == visit.vehicleId &&
        other.siteId != visit.siteId &&
        other.startedAt.isBefore(visit.endedAt ?? visit.lastInsideAt) &&
        visit.startedAt.isBefore(other.endedAt ?? other.lastInsideAt),
  );
  for (final s in daily) {
    final matches = eligible
        .where(
          (v) =>
              s.vehicleId != null &&
              s.siteId != null &&
              v.vehicleId == s.vehicleId &&
              v.siteId == s.siteId,
        )
        .toList();
    candidates[s.id] = matches;
    for (final v in matches) {
      uses[v.id] = (uses[v.id] ?? 0) + 1;
    }
  }
  final result = <GpsDailyMatch>[];
  for (final s in daily) {
    final matches = candidates[s.id]!;
    final missingLink = s.vehicleId == null || s.siteId == null;
    final uncertain = matches.any(
      (v) =>
          v.hasGap ||
          v.status == 'interrupted' ||
          gpsOperationalDay(v.startedAt) !=
              gpsOperationalDay(v.endedAt ?? v.lastInsideAt),
    );
    final ambiguous =
        matches.length > 1 ||
        matches.any((v) => uses[v.id]! > 1 || overlapsAnotherPlace(v));
    final kind = missingLink || uncertain || ambiguous
        ? GpsMatchKind.review
        : matches.isEmpty
        ? GpsMatchKind.noVisit
        : GpsMatchKind.matched;
    result.add(
      GpsDailyMatch(
        s,
        matches,
        kind,
        missingLink
            ? 'Falta vincular la unidad o empresa del servicio.'
            : ambiguous
            ? 'Hay varias visitas, servicios o geocercas simultáneas posibles; no se asignó una coincidencia automática.'
            : uncertain
            ? 'La visita tiene interrupciones o abarca más de un día; revisa los tiempos.'
            : matches.isEmpty
            ? 'No se encontró una visita en los datos disponibles. Esto no demuestra incumplimiento.'
            : 'La unidad y empresa coinciden en la fecha prevista. Confirma presencia, no la ejecución del servicio.',
      ),
    );
  }
  for (final v in eligible.where((v) => !uses.containsKey(v.id))) {
    final uncertain =
        v.hasGap ||
        v.status == 'interrupted' ||
        overlapsAnotherPlace(v) ||
        v.siteId == null ||
        v.vehicleId == null;
    result.add(
      GpsDailyMatch(
        null,
        [v],
        uncertain ? GpsMatchKind.review : GpsMatchKind.noService,
        uncertain
            ? 'La visita requiere revisar continuidad o vínculos antes de compararla.'
            : 'No hay un servicio no cancelado con la misma unidad, empresa y fecha prevista.',
      ),
    );
  }
  result.sort((a, b) {
    final unit = a.unit.compareTo(b.unit);
    if (unit != 0) return unit;
    final company = a.company.compareTo(b.company);
    return company != 0 ? company : a.id.compareTo(b.id);
  });
  return result;
}

class GpsDailyServiceStore {
  static Future<List<GpsDailyService>> load(DateTime day) async {
    final client = Supabase.instance.client;
    final date = gpsDayKey(day);
    final rows = await Future.wait([
      fetchAllSupabaseRows(
        (from, to) => client
            .from('services')
            .select('*')
            .eq('area', 'LOGISTICA')
            .or('due_date.eq.$date,and(due_date.is.null,service_date.eq.$date)')
            .order('id')
            .range(from, to),
      ),
      fetchAllSupabaseRows(
        (from, to) =>
            client.from('sites').select('id,name').order('id').range(from, to),
      ),
      fetchAllSupabaseRows(
        (from, to) => client
            .from('vehicles')
            .select('id,code')
            .order('id')
            .range(from, to),
      ),
    ]);
    final sites = {
      for (final r in rows[1]) r['id'].toString(): r['name'].toString(),
    };
    final vehicles = {
      for (final r in rows[2]) r['id'].toString(): r['code'].toString(),
    };
    return rows[0]
        .map((r) => GpsDailyService.fromRow(r, sites, vehicles))
        .toList();
  }
}
