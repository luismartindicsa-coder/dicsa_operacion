import 'package:supabase_flutter/supabase_flutter.dart';

Future<List<Map<String, dynamic>>> fetchAllSupabaseRows(
  PostgrestTransformBuilder<List<Map<String, dynamic>>> Function(
    int from,
    int to,
  )
  buildQuery, {
  int pageSize = 1000,
}) async {
  final collected = <Map<String, dynamic>>[];
  var from = 0;

  while (true) {
    final rows = await buildQuery(from, from + pageSize - 1);
    collected.addAll(rows);
    if (rows.length < pageSize) break;
    from += pageSize;
  }

  return collected;
}
