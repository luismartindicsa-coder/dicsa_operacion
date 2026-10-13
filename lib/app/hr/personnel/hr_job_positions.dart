import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/utils/fetch_all_supabase_rows.dart';

String normalizeHrJobPosition(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
String hrJobPositionKey(String value) {
  var key = normalizeHrJobPosition(value);
  const accented = 'ÁÉÍÓÚÜ';
  const plain = 'AEIOUU';
  for (var i = 0; i < accented.length; i++) {
    key = key.replaceAll(accented[i], plain[i]);
  }
  return key;
}

List<String> hrJobPositionOptions(Iterable<String> names) {
  final unique = <String, String>{};
  for (final name in names) {
    final normalized = normalizeHrJobPosition(name);
    if (normalized.isNotEmpty) {
      unique.putIfAbsent(hrJobPositionKey(normalized), () => normalized);
    }
  }
  return unique.values.toList()
    ..sort((a, b) => hrJobPositionKey(a).compareTo(hrJobPositionKey(b)));
}

class HrJobPositionRepository {
  final SupabaseClient client;
  HrJobPositionRepository(this.client);

  Future<List<String>> load() async => hrJobPositionOptions(
    (await fetchAllSupabaseRows(
      (from, to) => client
          .from('hr_job_positions')
          .select('name')
          .order('name_key')
          .range(from, to),
    )).map((row) => row['name'] as String),
  );

  Future<String> create(String name) async {
    final normalized = normalizeHrJobPosition(name);
    if (normalized.isEmpty || normalized.length > 120) {
      throw const FormatException('Escribe un puesto de hasta 120 caracteres.');
    }
    return await client.rpc(
          'hr_job_position_ensure',
          params: {'p_name': normalized},
        )
        as String;
  }
}
