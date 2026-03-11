import '../../ui_contract_core/refresh/deferred_refresh_controller.dart';
import '../../ui_contract_core/refresh/edit_safe_refresh_guard.dart';
import '../../ui_contract_core/refresh/realtime_refresh_coordinator.dart';

class GridTabbedRefreshController {
  final DeferredRefreshController deferred = DeferredRefreshController();
  final EditSafeRefreshGuard editGuard = EditSafeRefreshGuard();

  late final RealtimeRefreshCoordinator realtime = RealtimeRefreshCoordinator(
    controller: deferred,
    editGuard: editGuard,
  );

  Future<void> requestRefresh(Future<void> Function() action) {
    return realtime.request(action);
  }

  Future<void> flushPending(Future<void> Function() action) {
    return realtime.flushIfNeeded(action);
  }
}
