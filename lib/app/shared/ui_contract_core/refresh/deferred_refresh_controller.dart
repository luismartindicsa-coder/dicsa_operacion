class DeferredRefreshController {
  bool _refreshing = false;
  bool _pending = false;
  Object? _lastReason;

  bool get refreshing => _refreshing;
  bool get pending => _pending;
  Object? get lastReason => _lastReason;

  Future<void> run(Future<void> Function() action, {Object? reason}) async {
    if (_refreshing) {
      _pending = true;
      _lastReason = reason ?? _lastReason;
      return;
    }
    _refreshing = true;
    _lastReason = reason;
    try {
      await action();
    } finally {
      _refreshing = false;
      if (_pending) {
        _pending = false;
        await run(action, reason: _lastReason);
      }
    }
  }
}
