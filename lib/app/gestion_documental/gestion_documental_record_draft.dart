import 'package:file_picker/file_picker.dart';
import 'gestion_documental_records.dart';

/// Mutable capture, initialized empty or from a saved version. Changes remain
/// local until the repository confirms the complete record and its attachments.
class DocumentalRecordDraft {
  final DocumentalRecordKind kind;
  int? progressPercentage;
  String? relatedEmployeeId;
  String relatedEmployeeName = '';
  String studyType = '';
  String providerName = '';
  String periodicity = '';
  String authorizationNumber = '';
  String installationName = '';
  String? vehicleId;
  String vehicleLabel = '';
  String auditResult = '';
  String auditFindings = '';
  String maintenanceSubject = '';
  DateTime? scheduledDate;
  DateTime? performedDate;
  String insuredSubject = '';
  String coverageDescription = '';
  String counterpartyName = '';
  DateTime? signatureDate;
  String renewalType = '';
  DateTime? renewalDate;
  String renewalNotes = '';
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
    relatedEmployeeId = r.employeeId;
    relatedEmployeeName = r.employeeName;
    studyType = r.studyType;
    providerName = r.providerName;
    periodicity = r.periodicity;
    authorizationNumber = r.authorizationNumber;
    installationName = r.installationName;
    vehicleId = r.vehicleId;
    vehicleLabel = r.vehicleLabel;
    auditResult = r.auditResult;
    auditFindings = r.auditFindings;
    maintenanceSubject = r.maintenanceSubject;
    scheduledDate = r.scheduledDate;
    performedDate = r.performedDate;
    insuredSubject = r.insuredSubject;
    coverageDescription = r.coverageDescription;
    counterpartyName = r.counterpartyName;
    signatureDate = r.signatureDate;
    renewalType = r.renewalType;
    renewalDate = r.renewalDate;
    renewalNotes = r.renewalNotes;
    issueDate = r.date('issue_date');
    startDate = r.date('start_date');
    expirationDate = r.expiration;
    hasExpiration = expirationDate != null;
    savedFiles.addAll(detail.files.where((f) => f.current));
  }
  Map<String, dynamic> toRecordJson() => {
    'category': kind.key,
    if (kind.tracksProgress) 'progress_percentage': progressPercentage,
    if (kind == DocumentalRecordKind.safety ||
        kind == DocumentalRecordKind.personnel)
      'related_employee_id': relatedEmployeeId,
    if (kind == DocumentalRecordKind.safety) ...{'study_type': studyType},
    if (kind == DocumentalRecordKind.maintenance) ...{
      'maintenance_subject': maintenanceSubject.trim(),
    },
    if (kind == DocumentalRecordKind.audits) ...{
      'audit_result': auditResult,
      'audit_findings': auditFindings.trim(),
    },
    if (kind == DocumentalRecordKind.maintenance ||
        kind == DocumentalRecordKind.audits) ...{
      'scheduled_date': documentalDateJson(scheduledDate),
      'performed_date': documentalDateJson(performedDate),
    },
    if (kind == DocumentalRecordKind.safety ||
        kind == DocumentalRecordKind.maintenance) ...{
      'provider_name': providerName.trim(),
      'periodicity': periodicity,
    },
    if (kind == DocumentalRecordKind.environment) ...{
      'authorization_number': authorizationNumber.trim(),
      'installation_name': installationName.trim(),
    },
    if (kind == DocumentalRecordKind.vehicles) 'vehicle_id': vehicleId,
    if (kind == DocumentalRecordKind.contracts) ...{
      'counterparty_name': counterpartyName.trim(),
      'signature_date': documentalDateJson(signatureDate),
    },
    if (kind == DocumentalRecordKind.insurance) ...{
      'insured_subject': insuredSubject.trim(),
      'coverage_description': coverageDescription.trim(),
    },
    if (kind == DocumentalRecordKind.contracts ||
        kind == DocumentalRecordKind.insurance) ...{
      'renewal_type': renewalType,
      'renewal_date': documentalDateJson(renewalDate),
      'renewal_notes': renewalNotes.trim(),
    },
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
                studyType,
                providerName,
                periodicity,
                authorizationNumber,
                installationName,
                auditResult,
                auditFindings,
                maintenanceSubject,
                insuredSubject,
                coverageDescription,
                counterpartyName,
                renewalType,
                renewalNotes,
              ].any((value) => value.isNotEmpty) ||
              documentType != null ||
              status != null ||
              priority != null ||
              issueDate != null ||
              scheduledDate != null ||
              performedDate != null ||
              signatureDate != null ||
              renewalDate != null ||
              startDate != null ||
              expirationDate != null ||
              hasExpiration ||
              principal != null ||
              attachments.isNotEmpty ||
              responsibleId != null)) ||
      (id == null && relatedEmployeeId != null) ||
      (id == null && vehicleId != null) ||
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

  String? get auditOrganizationError =>
      kind == DocumentalRecordKind.audits && authority.trim().isEmpty
      ? 'Indica el organismo o auditor.'
      : null;

  String? get maintenanceSubjectError =>
      kind == DocumentalRecordKind.maintenance &&
          maintenanceSubject.trim().isEmpty
      ? 'Indica el equipo, instalación o alcance.'
      : null;

  String? get counterpartyError =>
      kind == DocumentalRecordKind.contracts && counterpartyName.trim().isEmpty
      ? 'Escribe el nombre de la contraparte.'
      : null;

  String? get insurerError =>
      kind == DocumentalRecordKind.insurance && authority.trim().isEmpty
      ? 'Escribe el nombre de la aseguradora.'
      : null;

  String? get insuredSubjectError =>
      kind == DocumentalRecordKind.insurance && insuredSubject.trim().isEmpty
      ? 'Indica el bien, persona o unidad asegurada.'
      : null;

  String? get renewalError =>
      (kind == DocumentalRecordKind.contracts ||
              kind == DocumentalRecordKind.insurance) &&
          renewalType == 'No aplica' &&
          renewalDate != null
      ? 'Retira la fecha cuando la renovación no aplica.'
      : null;

  String? get progressError =>
      kind.tracksProgress &&
          (progressPercentage == null ||
              progressPercentage! < 0 ||
              progressPercentage! > 100)
      ? 'Captura un avance de 0 a 100.'
      : null;
}

List<String> documentalTypesFor(DocumentalRecordKind kind) => switch (kind) {
  DocumentalRecordKind.legal => documentalLegalTypes,
  DocumentalRecordKind.procedures => documentalProcedureTypes,
  DocumentalRecordKind.safety => documentalSafetyTypes,
  DocumentalRecordKind.environment => documentalEnvironmentTypes,
  DocumentalRecordKind.vehicles => documentalVehicleTypes,
  DocumentalRecordKind.personnel => documentalPersonnelTypes,
  DocumentalRecordKind.civilProtection => documentalCivilProtectionTypes,
  DocumentalRecordKind.contracts => documentalContractTypes,
  DocumentalRecordKind.insurance => documentalInsuranceTypes,
  DocumentalRecordKind.maintenance => documentalMaintenanceTypes,
  DocumentalRecordKind.audits => documentalAuditTypes,
};

const documentalAuditTypes = [
  'Certificación',
  'Externa',
  'Interna',
  'Regulatoria',
  'Seguimiento',
];
const documentalAuditResults = [
  'Con observaciones',
  'Conforme',
  'No aplica',
  'No conforme',
];

const documentalMaintenanceTypes = [
  'Certificado',
  'Contrato',
  'Evidencia',
  'Inspección periódica',
  'Mantenimiento obligatorio',
  'Programa',
];

const documentalInsuranceTypes = [
  'Cobertura',
  'Endoso',
  'Póliza',
  'Renovación',
];

const documentalContractTypes = ['Anexo', 'Contrato', 'Convenio', 'Renovación'];
const documentalRenewalTypes = ['Automática', 'No aplica', 'Por acuerdo'];

const documentalCivilProtectionTypes = [
  'Brigada',
  'Capacitación',
  'Dictamen',
  'Plan de respuesta',
  'Programa interno',
  'Simulacro',
  'Visto bueno',
];

const documentalPersonnelTypes = [
  'Certificación',
  'Constancia',
  'Contrato laboral',
  'Documento laboral',
  'Identificación',
  'Licencia',
];

const documentalVehicleTypes = [
  'Licencia relacionada',
  'Mantenimiento documental',
  'Permiso',
  'Seguro',
  'Tarjeta de circulación',
  'Tenencia',
  'Verificación',
];

const documentalEnvironmentTypes = [
  'Agua',
  'Autorización',
  'Emisiones',
  'Estudio',
  'Licencia',
  'Manifiesto',
  'Permiso',
  'Residuos',
];

const documentalSafetyTypes = [
  'Capacitación',
  'DC3',
  'Dictamen',
  'Documentación STPS',
  'Equipo',
  'Estudio',
  'Inspección',
  'Obligación',
  'Programa',
];
const documentalStudyTypes = [
  'Condiciones térmicas',
  'Ergonomía',
  'Iluminación',
  'Otro',
  'Ruido',
  'Sustancias químicas',
  'Vibraciones',
];
const documentalPeriodicities = [
  'Anual',
  'Bimestral',
  'Mensual',
  'Por evento',
  'Semestral',
  'Sin periodicidad',
  'Trimestral',
  'Única',
];

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
