import 'dart:async';
import 'package:flutter/material.dart';
import '../shared/archetypes/workflow_master_detail/workflow_refresh_controller.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import 'gestion_documental_records.dart';
import 'gestion_documental_store.dart';
import 'gestion_documental_overview.dart';
import 'gestion_documental_catalog.dart';
import 'gestion_documental_record_capture.dart';
import 'gestion_documental_widgets.dart';

/// Reuses the workflow edit guard. Query generations prevent old filter/month
/// responses from appearing under a newly selected day or category.
class DocumentalLiveOverview<T> extends ChangeNotifier {
  final DocumentalRepository repository;
  final Future<T> Function() load;
  final DocumentalContext Function(T) contextOf;
  final _refresh = WorkflowRefreshController();
  StreamSubscription<void>? _subscription;
  Timer? _midnight, _retry;
  bool _disposed = false;
  int _generation = 0;
  T? data;
  String? error, actionError;
  bool loading = true, editing = false;
  DocumentalLiveOverview({
    required this.repository,
    required this.load,
    required this.contextOf,
  }) {
    _subscription = repository.changes.listen((_) => refresh());
  }
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh({bool reset = false}) {
    if (_disposed) return Future.value();
    if (reset) {
      _generation++;
      data = null;
      error = null;
      loading = true;
      _notify();
    }
    return _refresh.requestRefresh(_load);
  }

  Future<void> _load() async {
    if (_disposed) return;
    final generation = _generation;
    loading = true;
    _notify();
    try {
      final value = await load().timeout(const Duration(seconds: 30));
      if (_disposed || generation != _generation) return;
      data = value;
      error = null;
      _retry?.cancel();
      _midnight?.cancel();
      _midnight = Timer(contextOf(value).untilMidnight, () => refresh());
    } catch (e) {
      if (_disposed || generation != _generation) return;
      data = null;
      error = documentalErrorMessage(e);
      _retry?.cancel();
      _retry = Timer(const Duration(seconds: 30), () => refresh());
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> open(BuildContext context, DocumentalEvent event) =>
      openRecord(context, event.record);

  Future<void> openRecord(BuildContext context, DocumentalRecord record) async {
    if (editing || _disposed) return;
    editing = true;
    actionError = null;
    _refresh.editGuard.beginEditing();
    _notify();
    try {
      final values = await Future.wait<Object>([
        repository.loadDetail(record.id),
        repository.loadContext(kind: record.kind),
      ]).timeout(const Duration(seconds: 30));
      if (!context.mounted || _disposed) return;
      await showDocumentalRecordCapture(
        context,
        repository: repository,
        metadata: values[1] as DocumentalContext,
        detail: values[0] as DocumentalDetail,
      );
    } catch (e) {
      if (!_disposed) actionError = documentalErrorMessage(e);
    } finally {
      editing = false;
      _refresh.editGuard.endEditing();
      if (!_disposed) {
        _notify();
        if (_refresh.realtime.queuedWhileEditing) {
          await _refresh.flushPending(_load);
        } else {
          await refresh();
        }
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _midnight?.cancel();
    _retry?.cancel();
    super.dispose();
  }
}

class DocumentalOverviewFeedback extends StatelessWidget {
  final bool loading;
  final String? error;
  const DocumentalOverviewFeedback({
    super.key,
    required this.loading,
    this.error,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (loading) const LinearProgressIndicator(minHeight: 2),
      if (error != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
    ],
  );
}

class DocumentalEventTile extends StatelessWidget {
  final DocumentalEvent event;
  final DocumentalContext metadata;
  final VoidCallback onOpen;
  const DocumentalEventTile({
    super.key,
    required this.event,
    required this.metadata,
    required this.onOpen,
  });
  @override
  Widget build(BuildContext context) {
    final category = documentalCategories.firstWhere(
      (c) => c.key == event.record.kind.key,
    );
    final t = AreaThemeScope.of(context);
    final dates = MaterialLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DocumentalActionCard(
        key: ValueKey('event-${event.id}'),
        label: 'Abrir ${event.record.title} · ${event.kind.label}',
        padding: const EdgeInsets.all(14),
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(category.icon, size: 20, color: t.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.record.title,
                    style: TextStyle(
                      color: t.onGlass,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(Icons.open_in_new_rounded, size: 18, color: t.primary),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              category.title,
              style: TextStyle(color: t.primarySoft, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                DocumentalBadge(event.kind.label),
                DocumentalBadge(dates.formatCompactDate(event.date)),
                DocumentalBadge(event.record.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              metadata.responsibleName(event.record.responsibleId),
              style: TextStyle(color: t.primarySoft, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
