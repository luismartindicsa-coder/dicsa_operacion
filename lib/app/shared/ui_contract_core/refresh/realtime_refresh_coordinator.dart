import 'deferred_refresh_controller.dart';
import 'edit_safe_refresh_guard.dart';

class RealtimeRefreshCoordinator {
  final DeferredRefreshController controller;
  final EditSafeRefreshGuard editGuard;

  RealtimeRefreshCoordinator({
    required this.controller,
    required this.editGuard,
  });

  bool _queuedWhileEditing = false;

  bool get queuedWhileEditing => _queuedWhileEditing;

  Future<void> request(Future<void> Function() action) async {
    if (editGuard.isEditing) {
      _queuedWhileEditing = true;
      return;
    }
    await controller.run(action);
  }

  Future<void> flushIfNeeded(Future<void> Function() action) async {
    if (!_queuedWhileEditing || editGuard.isEditing) return;
    _queuedWhileEditing = false;
    await controller.run(action);
  }
}
