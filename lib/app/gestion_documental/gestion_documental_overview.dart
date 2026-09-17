import 'gestion_documental_records.dart';

/// Counts come from complete server queries, never from a paged category list.
class DocumentalCategoryCounts {
  final int total, upcoming, expired, pending;
  const DocumentalCategoryCounts({
    this.total = 0,
    this.upcoming = 0,
    this.expired = 0,
    this.pending = 0,
  });
  factory DocumentalCategoryCounts.fromJson(Map<String, dynamic> json) =>
      DocumentalCategoryCounts(
        total: json['total'] as int,
        upcoming: json['upcoming'] as int,
        expired: json['expired'] as int,
        pending: json['pending'] as int,
      );
}

enum DocumentalEventKind {
  expiration('vencimiento', 'Vencimiento'),
  renewal('renovacion', 'Renovación'),
  scheduled('programacion', 'Programación'),
  start('inicio', 'Inicio de vigencia'),
  performed('realizacion', 'Realización');

  final String key, label;
  const DocumentalEventKind(this.key, this.label);
}

class DocumentalEvent {
  final DocumentalRecord record;
  final DocumentalEventKind kind;
  final DateTime date;
  const DocumentalEvent({
    required this.record,
    required this.kind,
    required this.date,
  });
  String get id => '${record.id}-${kind.key}';
  factory DocumentalEvent.fromJson(Map<String, dynamic> json) =>
      DocumentalEvent(
        record: DocumentalRecord(
          Map<String, dynamic>.from(json['record'] as Map),
        ),
        kind: DocumentalEventKind.values.firstWhere(
          (k) => k.key == json['event_kind'],
        ),
        date: DateTime.parse(json['event_date'] as String),
      );
}

class DocumentalDashboardData {
  final DocumentalContext context;
  final Map<String, int> metrics;
  final Map<String, DocumentalCategoryCounts> categories;
  final List<DocumentalEvent> upcoming;
  final int upcomingTotal;
  const DocumentalDashboardData({
    required this.context,
    required this.metrics,
    required this.categories,
    required this.upcoming,
    required this.upcomingTotal,
  });
  factory DocumentalDashboardData.fromJson(Map<String, dynamic> json) =>
      DocumentalDashboardData(
        context: DocumentalContext.fromJson(
          Map<String, dynamic>.from(json['context'] as Map),
        ),
        metrics: Map<String, int>.from(json['metrics'] as Map),
        categories: (json['categories'] as Map).map(
          (key, value) => MapEntry(
            key as String,
            DocumentalCategoryCounts.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          ),
        ),
        upcoming: [
          for (final row in json['upcoming'] as List)
            DocumentalEvent.fromJson(Map<String, dynamic>.from(row as Map)),
        ],
        upcomingTotal: json['upcoming_total'] as int,
      );
  DocumentalCategoryCounts counts(String key) =>
      categories[key] ?? const DocumentalCategoryCounts();
}

class DocumentalCalendarQuery {
  final DateTime? month, selected;
  final String? category, status, responsibleId;
  final DocumentalEventKind? kind;
  final int page;
  const DocumentalCalendarQuery({
    this.month,
    this.selected,
    this.category,
    this.status,
    this.responsibleId,
    this.kind,
    this.page = 0,
  });
  Map<String, dynamic> toParams() => {
    'p_month': documentalDateJson(month),
    'p_selected': documentalDateJson(selected),
    'p_category': category,
    'p_status': status,
    'p_responsible': responsibleId,
    'p_event_kind': kind?.key,
    'p_page': page,
  };
}

class DocumentalCalendarData {
  final DocumentalContext context;
  final DateTime month, selected;
  final Map<String, int> days;
  final List<DocumentalEvent> events;
  final int total, monthTotal;
  const DocumentalCalendarData({
    required this.context,
    required this.month,
    required this.selected,
    required this.days,
    required this.events,
    required this.total,
    required this.monthTotal,
  });
  factory DocumentalCalendarData.fromJson(Map<String, dynamic> json) =>
      DocumentalCalendarData(
        context: DocumentalContext.fromJson(
          Map<String, dynamic>.from(json['context'] as Map),
        ),
        month: DateTime.parse(json['month'] as String),
        selected: DateTime.parse(json['selected'] as String),
        days: Map<String, int>.from(json['days'] as Map),
        events: [
          for (final row in json['events'] as List)
            DocumentalEvent.fromJson(Map<String, dynamic>.from(row as Map)),
        ],
        total: json['total'] as int,
        monthTotal: json['month_total'] as int,
      );
  int count(DateTime date) => days[documentalDateJson(date)] ?? 0;
}
