import 'package:supabase_flutter/supabase_flutter.dart';

import '../direction_shipments_store.dart';
import '../operating_program/operating_program_models.dart';

class DirectionExecutionRepository {
  SupabaseClient get client => Supabase.instance.client;

  Future<DirectionExecutionActual> save({
    required DirectionExecutionRow row,
    required int quantity,
    required List<int> loads,
    required String notes,
    String? programId,
    bool clear = false,
  }) async {
    final result = await client.rpc(
      'direction_save_execution_actual',
      params: {
        'p_kind': row.kind,
        'p_date': programDate(row.date),
        'p_material': row.material,
        'p_client': row.client,
        'p_shift': row.shift,
        'p_quantity': quantity,
        'p_loads': loads,
        'p_observed': row.observed,
        'p_notes': notes,
        'p_expected_revision': row.confirmation?.revision ?? 0,
        'p_program_id': programId,
        'p_clear': clear,
      },
    );
    return DirectionExecutionActual.fromRow(
      Map<String, dynamic>.from(result as Map),
    );
  }
}

List<int> parseDirectionActualLoads(String text) {
  if (text.trim() == '0') return [];
  final parts = text.split(',');
  if (parts.length > 1000 ||
      parts.any((p) => !RegExp(r'^\d+$').hasMatch(p.trim()))) {
    throw const FormatException(
      'Escribe las cantidades enteras separadas por comas; por ejemplo: 42, 38. Usa 0 si no hubo embarque.',
    );
  }
  final loads = parts.map((p) => int.parse(p.trim())).toList();
  if (loads.any((n) => n <= 0) || loads.fold(0, (a, b) => a + b) > 10000000) {
    throw const FormatException(
      'Cada embarque debe ser mayor a cero y el total no puede superar 10,000,000.',
    );
  }
  return loads;
}
