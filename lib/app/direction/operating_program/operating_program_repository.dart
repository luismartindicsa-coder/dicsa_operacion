import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../shared/utils/fetch_all_supabase_rows.dart';
import '../direction_shipments_store.dart';
import 'operating_program_models.dart';

class OperatingProgramRepository {
  SupabaseClient get client => Supabase.instance.client;

  Future<List<OperatingProgram>> loadVersions(DateTime week) async {
    final rows = await fetchAllSupabaseRows(
      (from, to) => client
          .from('direction_operating_programs')
          .select('*,lines:direction_operating_program_lines(*)')
          .eq('week_start', programDate(week))
          .order('version', ascending: false)
          .range(from, to),
    );
    return rows.map(OperatingProgram.fromJson).toList();
  }

  Future<OperatingProgram> saveDraft({
    required DateTime week,
    required int expectedVersion,
    required ProgramConditions conditions,
    required List<ProgramDemand> demands,
    required List<ProgramLine> lines,
  }) async {
    conditions.validate();
    final sorted = [...demands]..sort((a, b) => a.id.compareTo(b.id));
    final result = await client.rpc(
      'direction_save_operating_program',
      params: {
        'p_id': const Uuid().v4(),
        'p_week': programDate(week),
        'p_expected_version': expectedVersion,
        'p_conditions': conditions.toJson(),
        'p_shipments': sorted.map((d) => d.toJson()).toList(),
        'p_lines': lines.map((l) => l.toJson()).toList(),
      },
    );
    return OperatingProgram.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<OperatingProgram> approve(String id, {bool execute = false}) async {
    final result = await client.rpc(
      'direction_approve_operating_program',
      params: {'p_id': id, 'p_execute': execute},
    );
    return OperatingProgram.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<List<ProgramLine>> loadActual(DateTime week) async {
    final rows = await DirectionShipmentsStore.loadProgramProductionActuals(
      week,
    );
    final totals = <String, int>{};
    for (final row in rows) {
      final day = DateTime.parse(row['date'] as String).difference(week).inDays;
      final material = row['material'] as String;
      if (day < 0 || day > 4 || !programMaterials.contains(material)) continue;
      final shift = programShifts.indexOf(row['shift'] as String);
      if (shift < 0) continue;
      final key = '$day:$shift:$material';
      totals[key] = (totals[key] ?? 0) + (row['quantity'] as int);
    }
    return [
      for (var d = 0; d < 5; d++)
        for (var s = 0; s < 2; s++)
          for (final m in programMaterials)
            ProgramLine(d, s, m, totals['$d:$s:$m'] ?? 0),
    ];
  }
}
