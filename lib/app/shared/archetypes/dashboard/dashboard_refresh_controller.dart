import '../../ui_contract_core/refresh/deferred_refresh_controller.dart';

class DashboardRefreshController {
  final DeferredRefreshController deferred = DeferredRefreshController();

  Future<void> requestRefresh(Future<void> Function() action) {
    return deferred.run(action, reason: 'dashboard_refresh');
  }
}
