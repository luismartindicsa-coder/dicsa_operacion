import '../gestion_documental/gestion_documental_overview.dart';
import '../gestion_documental/gestion_documental_records.dart';

class DocumentalWeeklySource {
  final DocumentalContext context;
  final List<DocumentalRecord> records;
  const DocumentalWeeklySource({required this.context, required this.records});
}

/// Current document state, not a reconstruction of the state on a past Friday.
/// Uses the business day supplied by documental_context (Mexico City).
class DocumentalWeeklyAnalysis {
  final DocumentalWeeklySource source;
  DocumentalWeeklyAnalysis(this.source);

  DateTime get today => source.context.today;
  List<DocumentalRecord> get records => source.records;
  bool isActive(DocumentalRecord r) =>
      r.status == 'Pendiente' || r.status == 'En proceso';
  List<DocumentalRecord> get active => records.where(isActive).toList();
  List<DocumentalRecord> category(DocumentalRecordKind kind) =>
      records.where((r) => r.kind == kind).toList()..sort(compareRecords);
  int days(DateTime date) => documentalDaysRemaining(date, today);
  List<DocumentalRecord> get expired => active
      .where((r) => r.expiration != null && days(r.expiration!) < 0)
      .toList();
  List<DocumentalRecord> get critical => active
      .where(
        (r) =>
            r.expiration != null &&
            days(r.expiration!) >= 0 &&
            days(r.expiration!) <= 5,
      )
      .toList();
  List<DocumentalRecord> get upcoming => active
      .where(
        (r) =>
            r.expiration != null &&
            days(r.expiration!) >= 0 &&
            days(r.expiration!) <= 15,
      )
      .toList();
  List<DocumentalRecord> get withoutExpiration =>
      active.where((r) => r.expiration == null).toList();
  List<DocumentalRecord> get procedures =>
      category(DocumentalRecordKind.procedures).where(isActive).toList();
  List<DocumentalRecord> get manifests => category(
    DocumentalRecordKind.environment,
  ).where((r) => r.type == 'Manifiestos').toList();

  String responsible(DocumentalRecord r) {
    final id = r.data['responsible_user_id'] as String?;
    if (id == null || id.trim().isEmpty) return 'Sin responsable';
    return source.context.responsibleName(id);
  }

  String action(DocumentalRecord r) =>
      (r.data['next_action'] as String? ?? '').trim();

  /// Same derived dates as documental_event_dates; no invented recurrences.
  List<DocumentalEvent> get events {
    final result = <DocumentalEvent>[];
    for (final r in records) {
      void add(DocumentalEventKind kind, DateTime? date) {
        if (date != null) {
          result.add(DocumentalEvent(record: r, kind: kind, date: date));
        }
      }

      add(DocumentalEventKind.expiration, r.expiration);
      add(DocumentalEventKind.start, r.date('start_date'));
      if ((r.kind == DocumentalRecordKind.contracts ||
              r.kind == DocumentalRecordKind.insurance) &&
          r.renewalType != 'No aplica') {
        add(DocumentalEventKind.renewal, r.renewalDate);
      }
      if (r.kind == DocumentalRecordKind.maintenance ||
          r.kind == DocumentalRecordKind.audits) {
        add(DocumentalEventKind.scheduled, r.scheduledDate);
        add(DocumentalEventKind.performed, r.performedDate);
      }
    }
    return result..sort((a, b) {
      final date = a.date.compareTo(b.date);
      if (date != 0) return date;
      final record = compareRecordsByName(a.record, b.record);
      return record != 0 ? record : a.kind.key.compareTo(b.kind.key);
    });
  }

  List<DocumentalEvent> get agenda => events
      .where(
        (e) =>
            isActive(e.record) &&
            e.kind != DocumentalEventKind.performed &&
            days(e.date) >= 0 &&
            days(e.date) <= 29,
      )
      .toList();

  /// An expired document and an overdue renewal are distinct obligations.
  /// A recorded performance date resolves its scheduled activity only.
  List<DocumentalEvent> get risks => events.where((e) {
    if (!isActive(e.record)) return false;
    return switch (e.kind) {
      DocumentalEventKind.expiration => days(e.date) <= 15,
      DocumentalEventKind.renewal => days(e.date) <= 15,
      DocumentalEventKind.scheduled =>
        days(e.date) < 0 && e.record.performedDate == null,
      _ => false,
    };
  }).toList();

  int compareRecords(DocumentalRecord a, DocumentalRecord b) {
    final activeOrder = (isActive(a) ? 0 : 1).compareTo(isActive(b) ? 0 : 1);
    if (activeOrder != 0) return activeOrder;
    if (a.expiration != b.expiration) {
      if (a.expiration == null) return 1;
      if (b.expiration == null) return -1;
      final date = a.expiration!.compareTo(b.expiration!);
      if (date != 0) return date;
    }
    return compareRecordsByName(a, b);
  }

  int compareRecordsByName(DocumentalRecord a, DocumentalRecord b) {
    final title = a.title.toLowerCase().compareTo(b.title.toLowerCase());
    if (title != 0) return title;
    final reference = a.reference.compareTo(b.reference);
    return reference != 0 ? reference : a.id.compareTo(b.id);
  }
}
