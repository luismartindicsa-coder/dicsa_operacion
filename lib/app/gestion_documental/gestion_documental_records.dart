import 'package:flutter/material.dart';

enum DocumentalRecordKind {
  legal('documentacion-legal'),
  procedures('permisos-y-tramites'),
  safety('seguridad-e-higiene'),
  environment('medio-ambiente'),
  vehicles('vehiculos'),
  personnel('personal'),
  civilProtection('proteccion-civil'),
  contracts('contratos'),
  insurance('seguros'),
  maintenance('mantenimiento'),
  audits('auditorias');

  final String key;
  const DocumentalRecordKind(this.key);
  bool get tracksProgress => this != legal;
}

String? documentalDateJson(DateTime? value) => value == null
    ? null
    : '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

enum DocumentalUrgency {
  completed('Completado', Icons.check_circle_outline),
  noExpiration('Sin vencimiento', Icons.all_inclusive_rounded),
  expired('Vencido', Icons.event_busy_rounded),
  critical('Crítico', Icons.error_outline),
  attention('Atención', Icons.schedule_rounded),
  onTime('En tiempo', Icons.event_available_rounded);

  final String label;
  final IconData icon;
  const DocumentalUrgency(this.label, this.icon);
}

int documentalDaysRemaining(DateTime expiration, DateTime today) =>
    DateTime.utc(
      expiration.year,
      expiration.month,
      expiration.day,
    ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;

DocumentalUrgency documentalUrgency(
  String? status,
  DateTime? expiration,
  DateTime today,
) {
  if (status == 'Completado') return DocumentalUrgency.completed;
  if (expiration == null) return DocumentalUrgency.noExpiration;
  final days = documentalDaysRemaining(expiration, today);
  if (days < 0) return DocumentalUrgency.expired;
  if (days <= 5) return DocumentalUrgency.critical;
  if (days <= 15) return DocumentalUrgency.attention;
  return DocumentalUrgency.onTime;
}

class DocumentalResponsible {
  final String id;
  final String label;
  const DocumentalResponsible(this.id, this.label);
}

class DocumentalEmployee extends DocumentalResponsible {
  final bool isActive;
  const DocumentalEmployee(super.id, super.label, {this.isActive = true});
}

class DocumentalContext {
  final DateTime today;
  final Duration untilMidnight;
  final List<DocumentalResponsible> responsibles;
  final List<DocumentalEmployee> employees;
  final List<DocumentalResponsible> vehicles;
  const DocumentalContext({
    required this.today,
    required this.untilMidnight,
    required this.responsibles,
    this.employees = const [],
    this.vehicles = const [],
  });
  factory DocumentalContext.fromJson(Map<String, dynamic> json) {
    final people = [
      for (final r in json['responsibles'] as List)
        DocumentalResponsible(r['id'] as String, r['label'] as String),
    ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return DocumentalContext(
      today: DateTime.parse(json['today'] as String),
      untilMidnight: Duration(
        seconds: (json['seconds_to_midnight'] as num).ceil() + 1,
      ),
      responsibles: people,
      employees: [
        for (final employee in json['employees'] as List? ?? [])
          DocumentalEmployee(
            employee['id'] as String,
            employee['label'] as String,
            isActive: employee['is_active'] as bool? ?? true,
          ),
      ],
      vehicles: [
        for (final vehicle in json['vehicles'] as List? ?? [])
          DocumentalResponsible(
            vehicle['id'] as String,
            vehicle['label'] as String,
          ),
      ],
    );
  }
  String responsibleName(String? id) =>
      responsibles.where((r) => r.id == id).map((r) => r.label).firstOrNull ??
      'Usuario no disponible';
}

class DocumentalRecord {
  final Map<String, dynamic> data;
  DocumentalRecord(Map<String, dynamic> data) : data = Map.unmodifiable(data);
  String get id => data['id'] as String;
  DocumentalRecordKind get kind => DocumentalRecordKind.values.firstWhere(
    (kind) => kind.key == (data['category'] ?? DocumentalRecordKind.legal.key),
  );
  String get authority => data['authority'] as String? ?? '';
  String? get employeeId => data['related_employee_id'] as String?;
  String get employeeName => data['related_employee_name'] as String? ?? '';
  String get studyType => data['study_type'] as String? ?? '';
  String get providerName => data['provider_name'] as String? ?? '';
  String get periodicity => data['periodicity'] as String? ?? '';
  String get authorizationNumber =>
      data['authorization_number'] as String? ?? '';
  String get installationName => data['installation_name'] as String? ?? '';
  String? get vehicleId => data['vehicle_id'] as String?;
  String get vehicleLabel => data['vehicle_label'] as String? ?? '';
  String get counterpartyName => data['counterparty_name'] as String? ?? '';
  DateTime? get signatureDate => date('signature_date');
  String get renewalType => data['renewal_type'] as String? ?? '';
  DateTime? get renewalDate => date('renewal_date');
  String get renewalNotes => data['renewal_notes'] as String? ?? '';
  String get insuredSubject => data['insured_subject'] as String? ?? '';
  String get coverageDescription =>
      data['coverage_description'] as String? ?? '';
  String get maintenanceSubject => data['maintenance_subject'] as String? ?? '';
  DateTime? get scheduledDate => date('scheduled_date');
  DateTime? get performedDate => date('performed_date');
  String get auditResult => data['audit_result'] as String? ?? '';
  String get auditFindings => data['audit_findings'] as String? ?? '';
  int get progress => data['progress_percentage'] as int? ?? 0;
  String get title => data['title'] as String;
  String get type => data['document_type'] as String;
  String get status => data['status'] as String;
  String get priority => data['priority'] as String;
  String get responsibleId => data['responsible_user_id'] as String;
  String get reference => data['reference'] as String? ?? '';
  int get revision => data['revision'] as int;
  DateTime? date(String field) =>
      DateTime.tryParse(data[field]?.toString() ?? '');
  DateTime? get expiration => date('expiration_date');
}

class DocumentalFile {
  final Map<String, dynamic> data;
  DocumentalFile(Map<String, dynamic> data) : data = Map.unmodifiable(data);
  String get id => data['id'] as String;
  String get name => data['file_name'] as String;
  String get path => data['storage_path'] as String;
  String get role => data['role'] as String;
  bool get current => data['is_current'] as bool;
  int get revision => data['revision'] as int;
}

class DocumentalHistory {
  final Map<String, dynamic> data;
  DocumentalHistory(Map<String, dynamic> data) : data = Map.unmodifiable(data);
  int get revision => data['revision'] as int;
  String get event => data['event'] as String;
  String get actor => data['actor_name'] as String;
  DateTime get createdAt =>
      DateTime.parse(data['created_at'] as String).toLocal();
  DocumentalRecord get record => DocumentalRecord(
    Map<String, dynamic>.from((data['snapshot'] as Map)['record'] as Map),
  );
}

class DocumentalDetail {
  final DocumentalRecord record;
  final List<DocumentalFile> files;
  final List<DocumentalHistory> history;
  const DocumentalDetail({
    required this.record,
    required this.files,
    required this.history,
  });
  factory DocumentalDetail.fromJson(Map<String, dynamic> json) =>
      DocumentalDetail(
        record: DocumentalRecord(
          Map<String, dynamic>.from(json['record'] as Map),
        ),
        files: [
          for (final f in json['files'] as List)
            DocumentalFile(Map<String, dynamic>.from(f as Map)),
        ],
        history: [
          for (final h in json['history'] as List)
            DocumentalHistory(Map<String, dynamic>.from(h as Map)),
        ],
      );
}

class DocumentalQuery {
  final DocumentalRecordKind kind;
  final String search;
  final String? status, type, responsibleId, urgency, priority;
  final String sort;
  final int page;
  const DocumentalQuery({
    this.kind = DocumentalRecordKind.legal,
    this.priority,
    this.search = '',
    this.status,
    this.type,
    this.responsibleId,
    this.urgency,
    this.page = 0,
    this.sort = 'recent',
  });
  Map<String, dynamic> toParams() => {
    'p_category': kind.key,
    'p_priority': priority,
    'p_search': search,
    'p_status': status,
    'p_type': type,
    'p_responsible': responsibleId,
    'p_urgency': urgency,
    'p_page': page,
    'p_sort': sort,
  };
}

class DocumentalResultPage {
  final List<DocumentalRecord> records;
  final int total;
  const DocumentalResultPage(this.records, this.total);
}
