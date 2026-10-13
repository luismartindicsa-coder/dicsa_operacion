import '../shared/persistence/atomic_save.dart';

AtomicSave prepareMaintenanceSave({
  required Map<String, dynamic> originalOrder,
  required Map<String, dynamic> header,
  required Map<String, List<Map<String, dynamic>>> originalDetails,
  required Map<String, List<Map<String, dynamic>>> details,
}) {
  final id = originalOrder['id'];
  final operations = preservingRowChanges(
    table: 'maintenance_orders',
    before: [originalOrder],
    after: [
      {'id': id, ...header},
    ],
  );
  for (final operation in operations) {
    operation['expected'] = originalOrder;
  }
  final checks = <Map<String, dynamic>>[];
  for (final entry in details.entries) {
    final before = originalDetails[entry.key] ?? [];
    checks.add({
      'table': entry.key,
      'column': 'ot_id',
      'ids': [id],
      'rows': before,
    });
    operations.addAll(
      preservingRowChanges(
        table: entry.key,
        before: before,
        after: entry.value,
      ),
    );
  }
  return AtomicSave(operations: operations, checks: checks);
}
