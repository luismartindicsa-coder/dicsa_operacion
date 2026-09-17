import '../gestion_documental/gestion_documental_records.dart';
import '../gestion_documental/gestion_documental_store.dart';

class DirectionDocumentalSummary {
  final DocumentalContext context;
  final List<DocumentalRecord> expiring;
  final List<DocumentalRecord> procedures;

  const DirectionDocumentalSummary._({
    required this.context,
    required this.expiring,
    required this.procedures,
  });

  factory DirectionDocumentalSummary.fromRecords({
    required DocumentalContext context,
    required Iterable<DocumentalRecord> documents,
    required Iterable<DocumentalRecord> procedures,
  }) {
    final expiring = <String, DocumentalRecord>{};
    for (final row in documents) {
      if (row.status != 'Pendiente' && row.status != 'En proceso') continue;
      final expiration = row.expiration;
      if (expiration == null) continue;
      final days = documentalDaysRemaining(expiration, context.today);
      if (days >= 0 && days <= 15) expiring[row.id] = row;
    }
    final inProgress = <String, DocumentalRecord>{
      for (final row in procedures)
        if (row.kind == DocumentalRecordKind.procedures &&
            row.status == 'En proceso')
          row.id: row,
    };
    // The nearest deadlines lead follow-up; undated procedures remain visible.
    int byDeadline(DocumentalRecord a, DocumentalRecord b) {
      final date = (a.expiration ?? DateTime(9999)).compareTo(
        b.expiration ?? DateTime(9999),
      );
      if (date != 0) return date;
      final reference = a.reference.compareTo(b.reference);
      return reference != 0 ? reference : a.id.compareTo(b.id);
    }

    return DirectionDocumentalSummary._(
      context: context,
      expiring: List.unmodifiable(expiring.values.toList()..sort(byDeadline)),
      procedures: List.unmodifiable(
        inProgress.values.toList()..sort(byDeadline),
      ),
    );
  }
}

class DirectionDocumentalSummaryStore {
  final DocumentalRepository repository;

  const DirectionDocumentalSummaryStore(this.repository);

  Future<DirectionDocumentalSummary> load() async {
    final overview = await repository.loadDashboard();
    // The dashboard preview mixes several event types and stops at 12 items.
    // Its complete category counts identify which expiration queries to load.
    final documentQueries = [
      for (final kind in DocumentalRecordKind.values)
        if (overview.counts(kind.key).upcoming > 0)
          for (final urgency in [
            DocumentalUrgency.critical,
            DocumentalUrgency.attention,
          ])
            _loadAll(kind: kind, urgency: urgency.label),
    ];
    final results = await Future.wait<List<DocumentalRecord>>([
      ...documentQueries,
      _loadAll(kind: DocumentalRecordKind.procedures, status: 'En proceso'),
    ]);
    return DirectionDocumentalSummary.fromRecords(
      context: overview.context,
      documents: results.take(results.length - 1).expand((rows) => rows),
      procedures: results.last,
    );
  }

  Future<List<DocumentalRecord>> _loadAll({
    required DocumentalRecordKind kind,
    String? urgency,
    String? status,
  }) async {
    final rows = <DocumentalRecord>[];
    for (var page = 0; ; page++) {
      final result = await repository.loadPage(
        DocumentalQuery(
          kind: kind,
          urgency: urgency,
          status: status,
          sort: 'expiration',
          page: page,
        ),
      );
      rows.addAll(result.records);
      if (rows.length >= result.total || result.records.isEmpty) break;
    }
    return rows;
  }
}
