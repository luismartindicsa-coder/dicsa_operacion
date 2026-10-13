part of 'maintenance_page.dart';

@visibleForTesting
Future<bool> maintenancePreservingSaveForTesting(
  State state,
  String description,
) {
  final page = state as _MaintenancePageState;
  page._tasks.first['description'] = description;
  return page._saveCurrentOrder(showToast: false, refreshAfterSave: false);
}

@visibleForTesting
Map<String, dynamic> maintenancePreservationStateForTesting(State state) {
  final page = state as _MaintenancePageState;
  return {
    'tasks': page._tasks,
    'conflict': page._autosaveConflict,
    'pending': page._pendingAtomicSave != null,
  };
}
