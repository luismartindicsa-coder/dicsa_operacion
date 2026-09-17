import 'dart:async';
import 'package:dicsa_operacion/app/gestion_documental/gestion_documental_records.dart';
import 'package:dicsa_operacion/app/gestion_documental/gestion_documental_store.dart';
import 'package:dicsa_operacion/app/gestion_documental/gestion_documental_overview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DocumentalTestRepository implements DocumentalRepository {
  final records = <String, DocumentalDetail>{};
  final requests = <String, DocumentalDetail>{};
  final events = StreamController<void>.broadcast();
  bool unavailable = false;
  bool failSave = false;
  int saves = 0;
  int dashboardLoads = 0, calendarLoads = 0;
  DateTime? todayOverride;
  Duration overviewMidnight = const Duration(days: 1);
  DateTime get today {
    final now = todayOverride ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  Stream<void> get changes => events.stream;
  @override
  Future<DocumentalContext> loadContext({
    DocumentalRecordKind kind = DocumentalRecordKind.legal,
  }) async {
    if (unavailable) {
      throw const PostgrestException(message: 'missing', code: 'PGRST202');
    }
    return DocumentalContext(
      today: today,
      untilMidnight: overviewMidnight,
      employees: [
        const DocumentalEmployee(
          '00000000-0000-4000-8000-000000000005',
          'Trabajador de prueba',
        ),
        if (kind == DocumentalRecordKind.personnel)
          const DocumentalEmployee(
            '00000000-0000-4000-8000-000000000006',
            'Trabajador de baja',
            isActive: false,
          ),
      ],
      vehicles: const [
        DocumentalResponsible(
          '00000000-0000-4000-8000-000000000007',
          'C1 · ABC-123',
        ),
        DocumentalResponsible(
          '00000000-0000-4000-8000-000000000008',
          'C2 · DEF-456',
        ),
      ],
      responsibles: const [
        DocumentalResponsible(
          '00000000-0000-4000-8000-000000000001',
          'Responsable de prueba',
        ),
      ],
    );
  }

  @override
  Future<DocumentalResultPage> loadPage(DocumentalQuery query) async {
    final all = records.values
        .map((r) => r.record)
        .where(
          (r) =>
              r.kind == query.kind &&
              [
                    'title',
                    'reference',
                    'authority',
                    'department',
                    'related_employee_name',
                    'provider_name',
                    'study_type',
                    'periodicity',
                    'authorization_number',
                    'installation_name',
                    'vehicle_label',
                    'counterparty_name',
                    'renewal_notes',
                    'audit_result',
                    'audit_findings',
                    if (r.kind == DocumentalRecordKind.audits) 'next_action',
                    'maintenance_subject',
                    'insured_subject',
                    'coverage_description',
                  ]
                  .map((key) => r.data[key]?.toString() ?? '')
                  .join(' ')
                  .toLowerCase()
                  .contains(query.search.toLowerCase()) &&
              (query.priority == null || r.priority == query.priority) &&
              (query.status == null || r.status == query.status) &&
              (query.type == null || r.type == query.type) &&
              (query.responsibleId == null ||
                  r.responsibleId == query.responsibleId) &&
              (query.urgency == null ||
                  documentalUrgency(
                        r.status,
                        r.expiration,
                        DateTime.now(),
                      ).label ==
                      query.urgency),
        )
        .toList();
    if (query.sort == 'scheduled') {
      all.sort((a, b) {
        final dates = (a.scheduledDate ?? DateTime(9999)).compareTo(
          b.scheduledDate ?? DateTime(9999),
        );
        if (dates != 0) return dates;
        final reference = a.reference.compareTo(b.reference);
        return reference != 0 ? reference : a.id.compareTo(b.id);
      });
    }
    return DocumentalResultPage(
      all.skip(query.page * 50).take(50).toList(),
      all.length,
    );
  }

  bool _active(DocumentalRecord r) =>
      r.status == 'Pendiente' || r.status == 'En proceso';
  bool _due(DocumentalRecord r, int days) =>
      _active(r) &&
      r.expiration != null &&
      documentalDaysRemaining(r.expiration!, today) >= 0 &&
      documentalDaysRemaining(r.expiration!, today) <= days;
  bool _expired(DocumentalRecord r) =>
      _active(r) && r.expiration != null && r.expiration!.isBefore(today);
  List<DocumentalEvent> _dates() {
    final events = <DocumentalEvent>[];
    for (final d in records.values) {
      final r = d.record;
      final scheduled =
          r.kind == DocumentalRecordKind.maintenance ||
          r.kind == DocumentalRecordKind.audits;
      final renewal =
          (r.kind == DocumentalRecordKind.contracts ||
              r.kind == DocumentalRecordKind.insurance) &&
          r.renewalType != 'No aplica';
      for (final entry in {
        DocumentalEventKind.expiration: r.expiration,
        DocumentalEventKind.start: r.date('start_date'),
        DocumentalEventKind.renewal: renewal ? r.renewalDate : null,
        DocumentalEventKind.scheduled: scheduled ? r.scheduledDate : null,
        DocumentalEventKind.performed: scheduled ? r.performedDate : null,
      }.entries) {
        if (entry.value != null) {
          events.add(
            DocumentalEvent(record: r, kind: entry.key, date: entry.value!),
          );
        }
      }
    }
    events.sort((a, b) {
      final date = a.date.compareTo(b.date);
      if (date != 0) return date;
      final title = a.record.title.toLowerCase().compareTo(
        b.record.title.toLowerCase(),
      );
      if (title != 0) return title;
      final reference = a.record.reference.compareTo(b.record.reference);
      if (reference != 0) return reference;
      return a.id.compareTo(b.id);
    });
    return events;
  }

  @override
  Future<DocumentalDashboardData> loadDashboard() async {
    dashboardLoads++;
    final context = await loadContext();
    final all = records.values.map((d) => d.record).toList();
    final upcoming = _dates()
        .where(
          (e) =>
              _active(e.record) &&
              e.kind != DocumentalEventKind.performed &&
              !e.date.isBefore(today) &&
              e.date.isBefore(today.add(const Duration(days: 30))),
        )
        .toList();
    return DocumentalDashboardData(
      context: context,
      metrics: {
        'active': all.where(_active).length,
        'upcoming': all.where((r) => _due(r, 15)).length,
        'critical': all.where((r) => _due(r, 5)).length,
        'expired': all.where(_expired).length,
        'pending_procedures': all
            .where(
              (r) =>
                  r.kind == DocumentalRecordKind.procedures &&
                  r.status == 'Pendiente',
            )
            .length,
        'in_progress_procedures': all
            .where(
              (r) =>
                  r.kind == DocumentalRecordKind.procedures &&
                  r.status == 'En proceso',
            )
            .length,
      },
      categories: {
        for (final kind in DocumentalRecordKind.values)
          kind.key: DocumentalCategoryCounts(
            total: all.where((r) => r.kind == kind).length,
            upcoming: all.where((r) => r.kind == kind && _due(r, 15)).length,
            expired: all.where((r) => r.kind == kind && _expired(r)).length,
            pending: all.where((r) => r.kind == kind && _active(r)).length,
          ),
      },
      upcoming: upcoming.take(12).toList(),
      upcomingTotal: upcoming.length,
    );
  }

  @override
  Future<DocumentalCalendarData> loadCalendar(
    DocumentalCalendarQuery query,
  ) async {
    calendarLoads++;
    final context = await loadContext();
    final date = query.month ?? query.selected ?? today;
    final month = DateTime(date.year, date.month);
    final end = DateTime(month.year, month.month + 1);
    final selected =
        query.selected ??
        (!today.isBefore(month) && today.isBefore(end) ? today : month);
    final filtered = _dates()
        .where(
          (e) =>
              !e.date.isBefore(month) &&
              e.date.isBefore(end) &&
              (query.category == null || e.record.kind.key == query.category) &&
              (query.status == null || e.record.status == query.status) &&
              (query.responsibleId == null ||
                  e.record.responsibleId == query.responsibleId) &&
              (query.kind == null || e.kind == query.kind),
        )
        .toList();
    final days = <String, int>{};
    for (final e in filtered) {
      final key = documentalDateJson(e.date)!;
      days[key] = (days[key] ?? 0) + 1;
    }
    final events = filtered
        .where(
          (e) => documentalDateJson(e.date) == documentalDateJson(selected),
        )
        .toList();
    return DocumentalCalendarData(
      context: context,
      month: month,
      selected: selected,
      days: days,
      events: events.skip(query.page * 50).take(50).toList(),
      total: events.length,
      monthTotal: filtered.length,
    );
  }

  @override
  Future<DocumentalDetail> loadDetail(String id) async => records[id]!;
  @override
  Future<Uri> fileUrl(DocumentalFile file) async =>
      Uri.parse('https://test.invalid/authorized-file');
  @override
  Future<DocumentalDetail> save(DocumentalSaveOperation op) async {
    saves++;
    if (failSave) throw StateError('Fallo de guardado de prueba');
    if (requests.containsKey(op.requestId)) return requests[op.requestId]!;
    final previous = records[op.id];
    if ((previous?.record.revision ?? 0) != op.revision) {
      throw const PostgrestException(message: 'conflict', code: 'PT409');
    }
    final row = DocumentalRecord({
      ...op.record,
      'id': op.id,
      'related_employee_name': switch (op.record['related_employee_id']) {
        '00000000-0000-4000-8000-000000000005' => 'Trabajador de prueba',
        '00000000-0000-4000-8000-000000000006' => 'Trabajador de baja',
        _ => '',
      },
      'vehicle_label': switch (op.record['vehicle_id']) {
        '00000000-0000-4000-8000-000000000007' => 'C1 · ABC-123',
        '00000000-0000-4000-8000-000000000008' => 'C2 · DEF-456',
        _ => '',
      },
      'revision': op.revision + 1,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
    final files = [
      for (final f in previous?.files ?? <DocumentalFile>[])
        DocumentalFile({
          ...f.data,
          'is_current':
              f.current &&
              !op.retiredIds.contains(f.id) &&
              !(f.role == 'principal' &&
                  op.files.any((s) => s.role == 'principal')),
        }),
      for (var i = 0; i < op.files.length; i++)
        DocumentalFile({
          'id': '${op.requestId}-$i',
          'role': op.files[i].role,
          'file_name': op.files[i].file.name,
          'storage_path': 'test/${op.id}/$i',
          'is_current': true,
          'revision': op.revision + 1,
          'uploaded_by': op.record['responsible_user_id'],
        }),
    ];
    final history = DocumentalHistory({
      'revision': row.revision,
      'event': previous == null
          ? (row.kind == DocumentalRecordKind.procedures
                ? 'Trámite registrado'
                : 'Documento registrado')
          : 'Expediente actualizado',
      'actor_name': 'Responsable de prueba',
      'created_at': DateTime.now().toIso8601String(),
      'snapshot': {
        'record': row.data,
        'files': [for (final f in files.where((f) => f.current)) f.data],
      },
    });
    final result = DocumentalDetail(
      record: row,
      files: files,
      history: [history, ...?previous?.history],
    );
    records[op.id] = result;
    requests[op.requestId] = result;
    events.add(null);
    return result;
  }
}
