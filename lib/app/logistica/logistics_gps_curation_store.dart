import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/utils/fetch_all_supabase_rows.dart';
import 'logistics_gps_visit_store.dart';

class GpsAssignment {
  final String id, serviceId, visitId, note;
  final DateTime assignedAt;
  final LogisticsGpsVisit visit;
  GpsAssignment.fromRow(Map<String, dynamic> row)
    : id = row['id'].toString(),
      serviceId = row['service_id'].toString(),
      visitId = row['visit_id'].toString(),
      note = row['note']?.toString() ?? '',
      assignedAt = DateTime.parse(row['assigned_at'].toString()),
      visit = LogisticsGpsVisit.fromRow(
        Map<String, dynamic>.from(row['visit_snapshot'] as Map),
      );
}

class GpsTrashEntry {
  final String id, eventId, kind, reason, unit, place;
  final DateTime discardedAt, startedAt;
  GpsTrashEntry.fromRow(Map<String, dynamic> row)
    : id = row['id'].toString(),
      eventId = (row['visit_id'] ?? row['stop_id']).toString(),
      kind = row['visit_id'] != null ? 'visit' : 'stop',
      reason = row['reason'].toString(),
      unit = (row['event_snapshot'] as Map)['unit_label'].toString(),
      place =
          (row['event_snapshot'] as Map)['place_label']?.toString() ??
          'Parada GPS',
      startedAt = DateTime.parse(
        (row['event_snapshot'] as Map)['started_at'].toString(),
      ),
      discardedAt = DateTime.parse(row['discarded_at'].toString());
}

class GpsCuration {
  final List<GpsAssignment> assignments;
  final List<GpsTrashEntry> trash;
  final bool available;
  const GpsCuration({
    this.assignments = const [],
    this.trash = const [],
    this.available = false,
  });
  bool hidden(String kind, String id) =>
      trash.any((e) => e.kind == kind && e.eventId == id);
  GpsAssignment? forService(String id) =>
      assignments.where((a) => a.serviceId == id).firstOrNull;
  bool assigned(String id) => assignments.any((a) => a.visitId == id);
}

class GpsCurationStore {
  static Future<GpsCuration> load() async {
    final client = Supabase.instance.client;
    try {
      final rows = await Future.wait([
        fetchAllSupabaseRows(
          (from, to) => client
              .from('logistics_gps_assignments')
              .select()
              .isFilter('revoked_at', null)
              .order('assigned_at', ascending: false)
              .order('id')
              .range(from, to),
        ),
        fetchAllSupabaseRows(
          (from, to) => client
              .from('logistics_gps_trash')
              .select()
              .isFilter('restored_at', null)
              .order('discarded_at', ascending: false)
              .order('id')
              .range(from, to),
        ),
      ]);
      return GpsCuration(
        available: true,
        assignments: rows[0].map(GpsAssignment.fromRow).toList(),
        trash: rows[1].map(GpsTrashEntry.fromRow).toList(),
      );
    } on PostgrestException catch (e) {
      // Installation can precede deployment of this optional schema.
      if (['42P01', 'PGRST205'].contains(e.code)) return const GpsCuration();
      rethrow;
    }
  }

  static Future<void> assign(
    String service,
    String? visit,
    String? expected,
    String note,
  ) async {
    await Supabase.instance.client.rpc(
      'assign_logistics_gps_visit',
      params: {
        'p_service': service,
        'p_visit': visit,
        'p_expected': expected,
        'p_note': note,
      },
    );
  }

  static Future<void> discard(String kind, String id, String reason) async {
    await Supabase.instance.client.rpc(
      'trash_logistics_gps_event',
      params: {'p_kind': kind, 'p_event': id, 'p_reason': reason},
    );
  }

  static Future<void> restore(String id) async {
    await Supabase.instance.client.rpc(
      'restore_logistics_gps_event',
      params: {'p_trash': id},
    );
  }
}
