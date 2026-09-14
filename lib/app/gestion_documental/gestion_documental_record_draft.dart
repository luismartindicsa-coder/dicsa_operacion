import 'package:file_picker/file_picker.dart';
import 'gestion_documental_records.dart';

/// Mutable capture, initialized empty or from a saved version. Changes remain
/// local until the repository confirms the complete record and its attachments.
class DocumentalRecordDraft {
  final DocumentalRecordKind kind;
  int? progressPercentage;
  String? id;
  int revision = 0;
  String? responsibleId;
  bool modified = false;
  final List<DocumentalFile> savedFiles = [];
  final Set<String> retiredFileIds = {};
  DocumentalRecordDraft({this.kind = DocumentalRecordKind.legal});
  DocumentalRecordDraft.fromDetail(DocumentalDetail detail)
    : kind = detail.record.kind {
    final r = detail.record;
    id = r.id;
    revision = r.revision;
    title = r.title;
    documentType = r.type;
    responsibleId = r.responsibleId;
    authority = r.data['authority'] as String;
    reference = r.reference;
    area = r.data['department'] as String;
    observations = r.data['observations'] as String;
    nextAction = r.data['next_action'] as String;
    status = r.status;
    priority = r.priority;
    progressPercentage = r.progress;
    issueDate = r.date('issue_date');
    startDate = r.date('start_date');
    expirationDate = r.expiration;
    hasExpiration = expirationDate != null;
    savedFiles.addAll(detail.files.where((f) => f.current));
  }
  Map<String, dynamic> toRecordJson() => {
    'category': kind.key,
    if (kind == DocumentalRecordKind.procedures)
      'progress_percentage': progressPercentage,
    'title': title.trim(),
    'document_type': documentType,
    'responsible_user_id': responsibleId,
    'authority': authority.trim(),
    'reference': reference.trim(),
    'department': area.trim(),
    'observations': observations.trim(),
    'next_action': nextAction.trim(),
    'status': status,
    'priority': priority,
    'issue_date': documentalDateJson(issueDate),
    'start_date': documentalDateJson(startDate),
    'expiration_date': hasExpiration
        ? documentalDateJson(expirationDate)
        : null,
  };
  String title = '';
  String? documentType;
  String authority = '';
  String reference = '';
  String area = '';
  String observations = '';
  String nextAction = '';
  String? status;
  String? priority;
  DateTime? issueDate;
  DateTime? startDate;
  DateTime? expirationDate;
  bool hasExpiration = false;
  PlatformFile? principal;
  final List<PlatformFile> attachments = [];

  bool get isDirty =>
      modified ||
      (id == null &&
          ([
                title,
                authority,
                reference,
                area,
                observations,
                nextAction,
              ].any((value) => value.isNotEmpty) ||
              documentType != null ||
              status != null ||
              priority != null ||
              issueDate != null ||
              startDate != null ||
              expirationDate != null ||
              hasExpiration ||
              principal != null ||
              attachments.isNotEmpty ||
              responsibleId != null)) ||
      (id == null && progressPercentage != null) ||
      principal != null ||
      attachments.isNotEmpty ||
      retiredFileIds.isNotEmpty;

  String? get expirationError {
    if (!hasExpiration) return null;
    if (expirationDate == null) return 'Selecciona la fecha de vencimiento.';
    if (startDate != null && expirationDate!.isBefore(startDate!)) {
      return 'El vencimiento no puede ser anterior al inicio de vigencia.';
    }
    return null;
  }

  String? get progressError =>
      kind == DocumentalRecordKind.procedures &&
          (progressPercentage == null ||
              progressPercentage! < 0 ||
              progressPercentage! > 100)
      ? 'Captura un avance de 0 a 100.'
      : null;
}

List<String> documentalTypesFor(DocumentalRecordKind kind) =>
    kind == DocumentalRecordKind.legal
    ? documentalLegalTypes
    : documentalProcedureTypes;

const documentalProcedureTypes = [
  'Expediente',
  'Licencia',
  'Permiso',
  'Renovación',
  'Trámite',
];

const documentalLegalTypes = [
  'Acta constitutiva',
  'Constancia de situación fiscal',
  'Contrato constitutivo',
  'Documento corporativo',
  'Documento notarial',
  'Escritura',
  'Identificación legal',
  'Modificación societaria',
  'Poder notarial',
];

const documentalProcessStatuses = [
  'Cancelado',
  'Completado',
  'En proceso',
  'No aplica',
  'Pendiente',
];
const documentalPriorities = ['Alta', 'Baja', 'Media', 'Urgente'];
