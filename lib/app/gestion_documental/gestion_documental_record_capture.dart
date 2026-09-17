import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../shared/archetypes/auxiliary_surfaces/confirmation_dialog.dart';
import '../shared/archetypes/auxiliary_surfaces/date_picker_surface.dart';
import '../shared/archetypes/auxiliary_surfaces/searchable_picker.dart';
import '../shared/ui_contract_core/dialogs/contract_dialog_shell.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import '../shared/utils/file_download_save.dart';
import 'gestion_documental_records.dart';
import 'gestion_documental_catalog.dart';
import 'gestion_documental_store.dart';
import 'gestion_documental_record_draft.dart';
import 'gestion_documental_widgets.dart';

/// Auxiliary capture/detail surface. Reference: Mantenimiento's record sections
/// and dialogs; shared contractual controls, with Documental's pink tokens.
/// The caller defers realtime refresh while the editable detail is open.
Future<DocumentalDetail?> showDocumentalRecordCapture(
  BuildContext context, {
  required DocumentalRepository repository,
  required DocumentalContext metadata,
  DocumentalDetail? detail,
  DocumentalRecordKind kind = DocumentalRecordKind.legal,
  bool startWithFollowUp = false,
}) {
  final tokens = AreaThemeScope.of(context);
  final theme = Theme.of(context);
  return showDialog<DocumentalDetail>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (_) => AreaThemeScope(
      tokens: tokens,
      child: Theme(
        data: theme,
        child: _RecordCapture(
          repository: repository,
          metadata: metadata,
          detail: detail,
          kind: detail?.record.kind ?? kind,
          startWithFollowUp: startWithFollowUp,
        ),
      ),
    ),
  );
}

class _RecordCapture extends StatefulWidget {
  final DocumentalRepository repository;
  final DocumentalContext metadata;
  final DocumentalDetail? detail;
  final DocumentalRecordKind kind;
  final bool startWithFollowUp;
  const _RecordCapture({
    required this.repository,
    required this.metadata,
    this.detail,
    required this.kind,
    required this.startWithFollowUp,
  });

  @override
  State<_RecordCapture> createState() => _RecordCaptureState();
}

class _RecordCaptureState extends State<_RecordCapture> {
  late DocumentalRecordDraft _draft = widget.detail == null
      ? DocumentalRecordDraft(kind: widget.kind)
      : DocumentalRecordDraft.fromDetail(widget.detail!);
  late DocumentalDetail? _saved = widget.detail;
  DocumentalSaveOperation? _operation;
  bool _saving = false;
  String? _saveError;
  String? _fileBusy;
  bool get _pending => _operation?.confirmationPending ?? false;
  bool get _savedView => _preview && !_draft.isDirty && _saved != null;
  final _scroll = ScrollController();
  final _titleFocus = FocusNode();
  final _progressFocus = FocusNode();
  final _surfaceFocus = FocusNode();
  late int _section = widget.startWithFollowUp ? 3 : 0;
  late bool _preview = widget.detail != null && !widget.startWithFollowUp;
  bool get _isProcedure => widget.kind == DocumentalRecordKind.procedures;
  bool get _isSafety => widget.kind == DocumentalRecordKind.safety;
  bool get _isEnvironment => widget.kind == DocumentalRecordKind.environment;
  bool get _isPersonnel => widget.kind == DocumentalRecordKind.personnel;
  bool get _linksEmployee => _isSafety || _isPersonnel;
  bool get _isVehicle => widget.kind == DocumentalRecordKind.vehicles;
  bool get _isAudit => widget.kind == DocumentalRecordKind.audits;
  bool get _hasSchedule => _isMaintenance || _isAudit;
  String get _followUpLabel =>
      _isAudit ? 'Resultados y seguimiento' : 'Seguimiento';
  String get _nextActionLabel =>
      _isAudit ? 'Acciones pendientes' : 'Próxima acción';
  bool get _isMaintenance => widget.kind == DocumentalRecordKind.maintenance;
  bool get _hasPeriodicity => _isSafety || _isMaintenance;
  String get _validityLabel =>
      _hasSchedule ? 'Programación y vigencia' : 'Vigencia';
  String get _providerLabel =>
      _isMaintenance ? 'Proveedor / servicio' : 'Proveedor / capacitador';
  bool get _isInsurance => widget.kind == DocumentalRecordKind.insurance;
  bool get _hasRenewal => _isContract || _isInsurance;
  bool get _isContract => widget.kind == DocumentalRecordKind.contracts;
  String get _startLabel =>
      _isContract ? 'Fecha inicial' : 'Inicio de vigencia';
  String get _endLabel => _isContract ? 'Fecha final' : 'Fecha de vencimiento';
  bool get _tracksProgress => widget.kind.tracksProgress;
  DocumentalCategory get _category =>
      documentalCategories.firstWhere((c) => c.key == widget.kind.key);
  String get _titleLabel => switch (widget.kind) {
    DocumentalRecordKind.legal => 'Nombre del documento',
    DocumentalRecordKind.procedures => 'Trámite / expediente',
    DocumentalRecordKind.safety => 'Documento / actividad',
    DocumentalRecordKind.environment => 'Documento ambiental',
    DocumentalRecordKind.vehicles => 'Documento vehicular',
    DocumentalRecordKind.personnel => 'Documento laboral',
    DocumentalRecordKind.civilProtection => 'Documento / actividad',
    DocumentalRecordKind.contracts => 'Contrato / acuerdo',
    DocumentalRecordKind.insurance => 'Póliza / seguro',
    DocumentalRecordKind.maintenance => 'Documento / actividad',
    DocumentalRecordKind.audits => 'Nombre de la auditoría',
  };
  String get _typeLabel => switch (widget.kind) {
    DocumentalRecordKind.legal => 'Tipo de documento',
    DocumentalRecordKind.procedures => 'Tipo de gestión',
    DocumentalRecordKind.contracts => 'Tipo de contrato',
    DocumentalRecordKind.insurance => 'Tipo de seguro',
    DocumentalRecordKind.audits => 'Tipo de auditoría',
    _ => 'Tipo de registro',
  };
  String get _authorityLabel => switch (widget.kind) {
    DocumentalRecordKind.legal => 'Notaría / autoridad',
    DocumentalRecordKind.procedures => 'Dependencia',
    DocumentalRecordKind.safety => 'Autoridad / entidad',
    DocumentalRecordKind.environment => 'Autoridad ambiental',
    DocumentalRecordKind.vehicles => 'Emisor / aseguradora',
    DocumentalRecordKind.personnel => 'Emisor / institución',
    DocumentalRecordKind.civilProtection => 'Autoridad / entidad',
    DocumentalRecordKind.contracts => 'Notaría / entidad',
    DocumentalRecordKind.insurance => 'Aseguradora',
    DocumentalRecordKind.maintenance => 'Emisor / certificador',
    DocumentalRecordKind.audits => 'Organismo / auditor',
  };
  String get _newTitle => switch (widget.kind) {
    DocumentalRecordKind.legal => 'Nuevo documento legal',
    DocumentalRecordKind.procedures => 'Nuevo trámite',
    DocumentalRecordKind.safety => 'Nuevo documento de seguridad',
    DocumentalRecordKind.environment => 'Nuevo documento ambiental',
    DocumentalRecordKind.vehicles => 'Nuevo documento vehicular',
    DocumentalRecordKind.personnel => 'Nuevo documento de personal',
    DocumentalRecordKind.civilProtection =>
      'Nuevo registro de Protección Civil',
    DocumentalRecordKind.contracts => 'Nuevo contrato',
    DocumentalRecordKind.insurance => 'Nuevo seguro',
    DocumentalRecordKind.maintenance => 'Nuevo registro de mantenimiento',
    DocumentalRecordKind.audits => 'Nueva auditoría',
  };
  String get _editTitle => switch (widget.kind) {
    DocumentalRecordKind.legal => 'Editar documento legal',
    DocumentalRecordKind.procedures => 'Editar trámite',
    DocumentalRecordKind.safety => 'Editar documento de seguridad',
    DocumentalRecordKind.environment => 'Editar documento ambiental',
    DocumentalRecordKind.vehicles => 'Editar documento vehicular',
    DocumentalRecordKind.personnel => 'Editar documento de personal',
    DocumentalRecordKind.civilProtection =>
      'Editar registro de Protección Civil',
    DocumentalRecordKind.contracts => 'Editar contrato',
    DocumentalRecordKind.insurance => 'Editar seguro',
    DocumentalRecordKind.maintenance => 'Editar registro de mantenimiento',
    DocumentalRecordKind.audits => 'Editar auditoría',
  };
  String get _referenceLabel => _isInsurance
      ? 'Número de póliza'
      : _isVehicle
      ? 'Folio / póliza / referencia'
      : widget.kind != DocumentalRecordKind.legal
      ? 'Folio / referencia'
      : 'Folio / escritura / referencia';
  bool _validate = false;
  bool _closing = false;
  bool _canPop = false;
  bool _pickingFile = false;
  String? _fileError;

  @override
  void initState() {
    super.initState();
    if (widget.detail != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          (widget.startWithFollowUp ? _progressFocus : _surfaceFocus)
              .requestFocus();
        }
      });
    }
  }

  Future<void> _pickResponsible() async {
    final value = await showSearchablePickerDialog<String>(
      context,
      title: 'Responsable interno',
      initialValue: _draft.responsibleId,
      options: [
        for (final r in widget.metadata.responsibles)
          SearchablePickerOption(value: r.id, label: r.label),
      ],
    );
    if (value != null && mounted) {
      setState(() {
        _draft.responsibleId = value;
        _draft.modified = true;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    _operation ??= DocumentalSaveOperation(_draft);
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final result = await widget.repository.save(_operation!);
      if (!mounted) return;
      setState(() {
        _saved = result;
        _draft = DocumentalRecordDraft.fromDetail(result);
        _operation = null;
        _preview = true;
        _validate = false;
      });
      _top();
      _surfaceFocus.requestFocus();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saveError = _pending
            ? 'No se pudo confirmar el guardado. Reintenta para verificar la misma solicitud sin duplicar el documento.'
            : documentalErrorMessage(error);
        if (!_pending) _operation = null;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openStoredFile(
    DocumentalFile file, {
    bool download = false,
  }) async {
    if (_fileBusy != null) return;
    setState(() => _fileBusy = file.id);
    try {
      final url = await widget.repository.fileUrl(file);
      if (download) {
        await saveRemoteFileAs(
          url: url.toString(),
          suggestedFileName: file.name,
        );
      } else if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw StateError('No se pudo abrir el archivo. Puedes descargarlo.');
      }
    } catch (error) {
      if (mounted) setState(() => _saveError = documentalErrorMessage(error));
    } finally {
      if (mounted) setState(() => _fileBusy = null);
    }
  }

  String _fileTimestamp(DocumentalFile file) {
    final date = DateTime.tryParse(
      file.data['uploaded_at']?.toString() ?? '',
    )?.toLocal();
    if (date == null) return '';
    final labels = MaterialLocalizations.of(context);
    return ' · ${labels.formatCompactDate(date)} ${labels.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
  }

  Widget _storedFile(DocumentalFile file, {bool canRetire = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(file.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(
          'Versión ${file.revision} · ${file.current ? 'Vigente' : 'Histórico'} · ${widget.metadata.responsibleName(file.data['uploaded_by'] as String?)}${_fileTimestamp(file)}',
          style: TextStyle(
            fontSize: 12,
            color: AreaThemeScope.of(context).primarySoft,
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: _fileBusy == null ? () => _openStoredFile(file) : null,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Abrir archivo'),
            ),
            TextButton.icon(
              onPressed: _fileBusy == null
                  ? () => _openStoredFile(file, download: true)
                  : null,
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Descargar'),
            ),
            if (canRetire)
              TextButton(
                onPressed: () =>
                    setState(() => _draft.retiredFileIds.add(file.id)),
                child: const Text('Retirar del expediente'),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _history() {
    if (_saved == null) {
      return const Text(
        'El primer movimiento se registrará al guardar el documento.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final h in _saved!.history)
          ExpansionTile(
            key: ValueKey('history-${h.revision}'),
            tilePadding: EdgeInsets.zero,
            title: Text('Versión ${h.revision} · ${h.event}'),
            subtitle: Text(
              '${h.actor} · ${MaterialLocalizations.of(context).formatCompactDate(h.createdAt)} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(h.createdAt))}',
            ),
            children: [
              _RecordFields(
                children: [
                  for (final entry in {
                    'title': _isProcedure
                        ? 'Trámite / expediente'
                        : 'Documento',
                    'document_type': 'Tipo',
                    'reference': 'Folio',
                    'authority': _authorityLabel,
                    'department': 'Área',
                    'status': 'Estatus del proceso',
                    'priority': 'Prioridad',
                    'observations': 'Observaciones',
                    'next_action': _nextActionLabel,
                  }.entries)
                    _info(entry.value, h.record.data[entry.key]?.toString()),
                  _info(
                    'Responsable',
                    widget.metadata.responsibleName(h.record.responsibleId),
                  ),
                  if (_tracksProgress) _info('Avance', '${h.record.progress}%'),
                  if (_linksEmployee)
                    _info('Trabajador relacionado', h.record.employeeName),
                  if (_isMaintenance)
                    _info(
                      'Equipo / instalación / alcance',
                      h.record.maintenanceSubject,
                    ),
                  if (_isAudit) ...[
                    _info(
                      'Resultado',
                      h.record.auditResult.isEmpty
                          ? 'Sin resultado'
                          : h.record.auditResult,
                    ),
                    _info('Hallazgos', h.record.auditFindings),
                  ],
                  if (_hasSchedule) ...[
                    _info(
                      'Fecha programada',
                      _dateLabel(h.record.scheduledDate),
                    ),
                    _info(
                      'Fecha realizada',
                      _dateLabel(h.record.performedDate),
                    ),
                  ],
                  if (_isSafety) _info('Tipo de estudio', h.record.studyType),
                  if (_hasPeriodicity) ...[
                    _info(_providerLabel, h.record.providerName),
                    _info('Periodicidad', h.record.periodicity),
                  ],
                  if (_isEnvironment) ...[
                    _info(
                      'Número de autorización',
                      h.record.authorizationNumber,
                    ),
                    _info('Instalación relacionada', h.record.installationName),
                  ],
                  if (_isVehicle)
                    _info('Unidad relacionada', h.record.vehicleLabel),
                  if (_isContract) ...[
                    _info('Contraparte', h.record.counterpartyName),
                    _info('Fecha de firma', _dateLabel(h.record.signatureDate)),
                  ] else
                    _info('Emisión', _dateLabel(h.record.date('issue_date'))),
                  if (_isInsurance) ...[
                    _info(
                      'Bien, persona o unidad asegurada',
                      h.record.insuredSubject,
                    ),
                    _info('Cobertura', h.record.coverageDescription),
                  ],
                  if (_hasRenewal) ...[
                    _info(
                      'Renovación',
                      h.record.renewalType.isEmpty
                          ? 'Sin especificar'
                          : h.record.renewalType,
                    ),
                    _info(
                      'Fecha de renovación',
                      _dateLabel(h.record.renewalDate),
                    ),
                    _info('Condiciones de renovación', h.record.renewalNotes),
                  ],
                  _info(_startLabel, _dateLabel(h.record.date('start_date'))),
                  _info(
                    _isContract ? _endLabel : 'Vencimiento',
                    _dateLabel(h.record.expiration) ?? 'Sin vencimiento',
                  ),
                ],
              ),
              for (final fileData
                  in (h.data['snapshot'] as Map)['files'] as List)
                _storedFile(
                  _saved!.files.firstWhere((f) => f.id == fileData['id']),
                ),
            ],
          ),
      ],
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    _titleFocus.dispose();
    _progressFocus.dispose();
    _surfaceFocus.dispose();
    super.dispose();
  }

  void _top() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _showPreview() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _validate = true;
      if (_draft.title.trim().isEmpty ||
          _draft.documentType == null ||
          _draft.responsibleId == null ||
          _draft.counterpartyError != null ||
          _draft.insurerError != null ||
          _draft.insuredSubjectError != null ||
          _draft.maintenanceSubjectError != null ||
          _draft.auditOrganizationError != null) {
        _section = 0;
      } else if (_draft.expirationError != null ||
          _draft.renewalError != null) {
        _section = 1;
      } else if (_draft.status == null ||
          _draft.priority == null ||
          _draft.progressError != null) {
        _section = 3;
      } else {
        _preview = true;
      }
    });
    _top();
    if (_preview) _surfaceFocus.requestFocus();
    if (!_preview && _draft.title.trim().isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _titleFocus.requestFocus();
      });
    }
  }

  void _edit() {
    if (_saving || _pending) return;
    setState(() => _preview = false);
    _top();
  }

  Future<void> _close() async {
    if (_closing || _pickingFile || _saving) return;
    _closing = true;
    final discard =
        !_draft.isDirty ||
        await showContractConfirmationDialog(
              context,
              title: 'Cerrar la captura',
              content: _pending
                  ? 'No se ha podido confirmar el guardado. Cerrar no revierte una operación que ya haya llegado al servidor. Puedes cancelar y reintentar con seguridad.'
                  : 'Hay cambios sin guardar. Al cerrar se descartará la captura.',
              confirmText: 'Descartar captura',
            ) ==
            true;
    if (!mounted) return;
    _closing = false;
    if (discard) {
      setState(() => _canPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(_saved);
      });
    }
  }

  Future<void> _pickOption(
    String title,
    List<String> options,
    String? current,
    ValueChanged<String> onSelected,
  ) async {
    final value = await showSearchablePickerDialog<String>(
      context,
      title: title,
      initialValue: current,
      options: [
        for (final option in options)
          SearchablePickerOption(value: option, label: option),
      ],
    );
    if (mounted && value != null) {
      setState(() {
        onSelected(value);
        _draft.modified = true;
      });
    }
  }

  Future<void> _pickOptional(
    String title,
    List<String> values,
    String current,
    ValueChanged<String> onSelected,
  ) async {
    final options = [
      const SearchablePickerOption(value: '', label: 'Sin especificar'),
      for (final value in values)
        SearchablePickerOption(value: value, label: value),
    ]..sort((a, b) => a.label.compareTo(b.label));
    final value = await showSearchablePickerDialog<String>(
      context,
      title: title,
      initialValue: current,
      options: options,
    );
    if (mounted && value != null) {
      setState(() {
        onSelected(value);
        _draft.modified = true;
      });
    }
  }

  Future<void> _pickEmployee() async {
    final people = widget.metadata.employees;
    final options = [
      const SearchablePickerOption(
        value: '',
        label: 'Sin trabajador específico',
      ),
      for (final employee in people)
        SearchablePickerOption(
          value: employee.id,
          label: employee.isActive
              ? employee.label
              : '${employee.label} (inactivo)',
        ),
      if (_draft.relatedEmployeeId != null &&
          !people.any((e) => e.id == _draft.relatedEmployeeId))
        SearchablePickerOption(
          value: _draft.relatedEmployeeId!,
          label: '${_draft.relatedEmployeeName} (inactivo)',
        ),
    ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    final value = await showSearchablePickerDialog<String>(
      context,
      title: 'Trabajador relacionado',
      initialValue: _draft.relatedEmployeeId ?? '',
      options: options,
    );
    if (mounted && value != null) {
      setState(() {
        _draft.relatedEmployeeId = value.isEmpty ? null : value;
        _draft.relatedEmployeeName = value.isEmpty
            ? ''
            : people.where((e) => e.id == value).firstOrNull?.label ??
                  _draft.relatedEmployeeName;
        _draft.modified = true;
      });
    }
  }

  Future<void> _pickVehicle() async {
    final vehicles = widget.metadata.vehicles;
    final options = [
      const SearchablePickerOption(value: '', label: 'Sin unidad específica'),
      for (final vehicle in vehicles)
        SearchablePickerOption(value: vehicle.id, label: vehicle.label),
    ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    final value = await showSearchablePickerDialog<String>(
      context,
      title: 'Unidad relacionada',
      initialValue: _draft.vehicleId ?? '',
      options: options,
    );
    if (mounted && value != null) {
      setState(() {
        _draft.vehicleId = value.isEmpty ? null : value;
        _draft.vehicleLabel = value.isEmpty
            ? ''
            : vehicles.firstWhere((v) => v.id == value).label;
        _draft.modified = true;
      });
    }
  }

  Future<void> _pickDate(
    String title,
    DateTime? current,
    ValueChanged<DateTime?> onSelected,
  ) async {
    final today = widget.metadata.today;
    final value = await showContractDatePickerSurface(
      context,
      title: title,
      initialDate: current ?? today,
      firstDate: DateTime(1900),
      lastDate: DateTime(today.year + 100, 12, 31),
    );
    if (mounted && value != null) {
      setState(() {
        onSelected(value);
        _draft.modified = true;
      });
    }
  }

  Future<void> _pickFiles({required bool principal}) async {
    if (_pickingFile) return;
    setState(() {
      _pickingFile = true;
      _fileError = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: !principal,
        withData: kIsWeb,
        lockParentWindow: true,
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      setState(() {
        _draft.modified = true;
        if (principal) {
          _draft.principal = result.files.first;
        } else {
          for (final file in result.files) {
            if (!_draft.attachments.any(
              (existing) =>
                  existing.name == file.name &&
                  existing.size == file.size &&
                  existing.path == file.path,
            )) {
              _draft.attachments.add(file);
            }
          }
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _fileError =
              'No se pudo abrir el selector de archivos. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _pickingFile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (_preview && !_savedView && !_pending) {
            _edit();
          } else {
            _close();
          }
        }
      },
      child: Focus(
        focusNode: _surfaceFocus,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent || _closing) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            if (_preview && !_savedView && !_pending) {
              _edit();
            } else {
              _close();
            }
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: ContractDialogShell(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      DocumentalIcon(_category.icon),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _preview
                                  ? (_isProcedure
                                        ? 'Detalle del trámite'
                                        : 'Detalle del documento')
                                  : _saved == null
                                  ? _newTitle
                                  : _editTitle,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: tokens.onGlass,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _category.title,
                              style: TextStyle(
                                fontSize: 12,
                                color: tokens.primarySoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _close,
                        tooltip: 'Cerrar captura',
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _savedView
                        ? 'Expediente guardado · Versión ${_saved!.record.revision}'
                        : 'Los cambios y archivos se registran al guardar el expediente.',
                    style: TextStyle(fontSize: 12, color: tokens.primarySoft),
                  ),
                  const SizedBox(height: 16),
                  if (_saveError != null) ...[
                    Text(
                      _saveError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (!_preview) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in [
                          'Datos generales',
                          _validityLabel,
                          'Documentación',
                          _followUpLabel,
                        ].asMap().entries)
                          ChoiceChip(
                            label: Text(entry.value),
                            selected: _section == entry.key,
                            selectedColor: tokens.primaryStrong,
                            backgroundColor: tokens.fieldSurface,
                            labelStyle: TextStyle(
                              color: tokens.onGlass,
                              fontWeight: FontWeight.w700,
                            ),
                            side: BorderSide(
                              color: tokens.border.withValues(alpha: 0.4),
                            ),
                            onSelected: (_) {
                              FocusManager.instance.primaryFocus?.unfocus();
                              setState(() => _section = entry.key);
                              _top();
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  Flexible(
                    child: Scrollbar(
                      controller: _scroll,
                      child: SingleChildScrollView(
                        controller: _scroll,
                        padding: const EdgeInsets.only(right: 6, bottom: 4),
                        child: AbsorbPointer(
                          absorbing: _saving || _pending,
                          child: _preview
                              ? _detail()
                              : switch (_section) {
                                  0 => _general(),
                                  1 => _validity(),
                                  2 => _documents(),
                                  _ => _followUp(),
                                },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        style: contractSecondaryButtonStyle(context),
                        onPressed: _saving
                            ? null
                            : _savedView || _pending
                            ? _close
                            : _preview
                            ? _edit
                            : _close,
                        child: Text(
                          _savedView || _pending
                              ? 'Cerrar'
                              : _preview
                              ? 'Volver a captura'
                              : 'Cancelar',
                        ),
                      ),
                      if (_preview)
                        ElevatedButton.icon(
                          style: contractPrimaryButtonStyle(context),
                          onPressed: _saving
                              ? null
                              : _savedView
                              ? _edit
                              : _save,
                          icon: const Icon(Icons.save_outlined, size: 18),
                          label: Text(
                            _saving
                                ? 'Guardando…'
                                : _savedView
                                ? 'Editar expediente'
                                : _pending
                                ? 'Reintentar guardar'
                                : (_isProcedure
                                      ? 'Guardar trámite'
                                      : 'Guardar documento'),
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          style: contractPrimaryButtonStyle(context),
                          onPressed: _pickingFile ? null : _showPreview,
                          icon: const Icon(Icons.preview_rounded, size: 18),
                          label: const Text('Vista previa'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _general() => _RecordSection(
    title: 'Datos generales',
    icon: Icons.description_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _text(
          _titleLabel,
          _draft.title,
          (v) => _draft.title = v,
          focusNode: _titleFocus,
          autofocus: true,
          error: _validate && _draft.title.trim().isEmpty
              ? (_isProcedure
                    ? 'Escribe el nombre del trámite.'
                    : 'Escribe el nombre del documento.')
              : null,
        ),
        const SizedBox(height: 12),
        _RecordFields(
          children: [
            _option(
              _typeLabel,
              _draft.documentType,
              () => _pickOption(
                _typeLabel,
                documentalTypesFor(widget.kind),
                _draft.documentType,
                (v) => _draft.documentType = v,
              ),
              error: _validate && _draft.documentType == null
                  ? (_isProcedure
                        ? 'Selecciona el tipo de gestión.'
                        : 'Selecciona el tipo de documento.')
                  : null,
            ),
            _text(
              _referenceLabel,
              _draft.reference,
              (v) => _draft.reference = v,
            ),
            if (_isContract)
              _text(
                'Contraparte',
                _draft.counterpartyName,
                (v) => _draft.counterpartyName = v,
                error: _validate ? _draft.counterpartyError : null,
              ),
            _text(
              _authorityLabel,
              _draft.authority,
              (v) => _draft.authority = v,
              error: _validate
                  ? (_draft.insurerError ?? _draft.auditOrganizationError)
                  : null,
            ),
            if (_isInsurance) ...[
              _text(
                'Bien, persona o unidad asegurada',
                _draft.insuredSubject,
                (v) => _draft.insuredSubject = v,
                error: _validate ? _draft.insuredSubjectError : null,
              ),
              _text(
                'Cobertura',
                _draft.coverageDescription,
                (v) => _draft.coverageDescription = v,
                multiline: true,
              ),
            ],
            _text('Área / departamento', _draft.area, (v) => _draft.area = v),
            _option(
              'Responsable interno',
              _draft.responsibleId == null
                  ? null
                  : widget.metadata.responsibleName(_draft.responsibleId),
              _pickResponsible,
              error: _validate && _draft.responsibleId == null
                  ? 'Selecciona un responsable.'
                  : null,
            ),
            if (_linksEmployee)
              _option(
                'Trabajador relacionado',
                _draft.relatedEmployeeId == null
                    ? null
                    : _draft.relatedEmployeeName,
                _pickEmployee,
                hint: 'Opcional · puede aplicar a un área',
              ),
            if (_isMaintenance)
              _text(
                'Equipo / instalación / alcance',
                _draft.maintenanceSubject,
                (v) => _draft.maintenanceSubject = v,
                error: _validate ? _draft.maintenanceSubjectError : null,
              ),
            if (_isSafety)
              _option(
                'Tipo de estudio',
                _draft.studyType.isEmpty ? null : _draft.studyType,
                () => _pickOptional(
                  'Tipo de estudio',
                  documentalStudyTypes,
                  _draft.studyType,
                  (v) => _draft.studyType = v,
                ),
                hint: 'Opcional',
              ),
            if (_hasPeriodicity) ...[
              _text(
                _providerLabel,
                _draft.providerName,
                (v) => _draft.providerName = v,
              ),
              _option(
                'Periodicidad',
                _draft.periodicity.isEmpty ? null : _draft.periodicity,
                () => _pickOptional(
                  'Periodicidad',
                  documentalPeriodicities,
                  _draft.periodicity,
                  (v) => _draft.periodicity = v,
                ),
                hint: 'Opcional',
              ),
            ],
            if (_isVehicle)
              _option(
                'Unidad relacionada',
                _draft.vehicleId == null ? null : _draft.vehicleLabel,
                _pickVehicle,
                hint: 'Opcional · puede aplicar a la flotilla',
              ),
            if (_isEnvironment) ...[
              _text(
                'Número de autorización',
                _draft.authorizationNumber,
                (v) => _draft.authorizationNumber = v,
              ),
              _text(
                'Instalación relacionada',
                _draft.installationName,
                (v) => _draft.installationName = v,
              ),
            ],
          ],
        ),
      ],
    ),
  );

  Widget _validity() => _RecordSection(
    title: _validityLabel,
    icon: Icons.event_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RecordFields(
          children: [
            if (_hasSchedule) ...[
              _date(
                'Fecha programada',
                _draft.scheduledDate,
                (v) => _draft.scheduledDate = v,
              ),
              _date(
                'Fecha realizada',
                _draft.performedDate,
                (v) => _draft.performedDate = v,
              ),
            ],
            if (_isContract)
              _date(
                'Fecha de firma',
                _draft.signatureDate,
                (v) => _draft.signatureDate = v,
              )
            else
              _date(
                'Fecha de emisión',
                _draft.issueDate,
                (v) => _draft.issueDate = v,
              ),
            _date(_startLabel, _draft.startDate, (v) => _draft.startDate = v),
          ],
        ),
        const SizedBox(height: 12),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Tiene vencimiento'),
          subtitle: const Text(
            'Actívalo solo cuando el documento tenga una fecha límite.',
          ),
          value: _draft.hasExpiration,
          onChanged: (v) => setState(() {
            _draft.modified = true;
            _draft.hasExpiration = v;
            if (!v) _draft.expirationDate = null;
          }),
        ),
        const SizedBox(height: 12),
        if (_draft.hasExpiration)
          _date(
            _endLabel,
            _draft.expirationDate,
            (v) => _draft.expirationDate = v,
            error: _validate ? _draft.expirationError : null,
          )
        else
          const Align(
            alignment: Alignment.centerLeft,
            child: DocumentalBadge(
              'Sin vencimiento',
              icon: Icons.all_inclusive_rounded,
            ),
          ),
        if (_hasRenewal) ...[
          const SizedBox(height: 16),
          _RecordFields(
            children: [
              _option(
                'Renovación',
                _draft.renewalType.isEmpty ? null : _draft.renewalType,
                () => _pickOptional(
                  'Renovación',
                  documentalRenewalTypes,
                  _draft.renewalType,
                  (v) {
                    _draft.renewalType = v;
                    if (v == 'No aplica') _draft.renewalDate = null;
                  },
                ),
                hint: 'Sin especificar',
              ),
              if (_draft.renewalType != 'No aplica')
                _date(
                  'Fecha de renovación',
                  _draft.renewalDate,
                  (v) => _draft.renewalDate = v,
                  error: _validate ? _draft.renewalError : null,
                ),
            ],
          ),
          const SizedBox(height: 12),
          _text(
            'Condiciones de renovación',
            _draft.renewalNotes,
            (v) => _draft.renewalNotes = v,
            multiline: true,
          ),
        ],
      ],
    ),
  );

  Widget _documents({bool readOnly = false}) => _RecordSection(
    title: 'Documentación',
    icon: Icons.attach_file_rounded,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(
          _isContract
              ? 'Archivo firmado (principal)'
              : _isInsurance
              ? 'Póliza (principal)'
              : _isAudit
              ? 'Evidencia / documento final (principal)'
              : 'Documento principal',
        ),
        const SizedBox(height: 8),
        if (_draft.principal == null &&
            !_draft.savedFiles.any((f) => f.role == 'principal'))
          Text(
            _isContract
                ? 'Sin archivo firmado seleccionado.'
                : 'Sin archivo principal seleccionado.',
          )
        else if (_draft.principal != null)
          _file(
            _draft.principal!,
            readOnly ? null : () => setState(() => _draft.principal = null),
          ),
        if (_draft.principal == null)
          for (final f in _draft.savedFiles.where((f) => f.role == 'principal'))
            _storedFile(f),
        if (!readOnly) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              style: contractSecondaryButtonStyle(context),
              onPressed: _pickingFile
                  ? null
                  : () => _pickFiles(principal: true),
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: Text(
                _draft.principal == null
                    ? 'Seleccionar archivo'
                    : 'Cambiar selección',
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        _label('Archivos complementarios'),
        const SizedBox(height: 8),
        if (_draft.attachments.isEmpty &&
            !_draft.savedFiles.any(
              (f) =>
                  f.role == 'complementario' &&
                  !_draft.retiredFileIds.contains(f.id),
            ))
          const Text('Sin archivos complementarios seleccionados.'),
        for (final f in _draft.savedFiles.where(
          (f) =>
              f.role == 'complementario' &&
              !_draft.retiredFileIds.contains(f.id),
        ))
          _storedFile(f, canRetire: !readOnly),
        for (final file in _draft.attachments)
          _file(
            file,
            readOnly
                ? null
                : () => setState(() => _draft.attachments.remove(file)),
          ),
        if (!readOnly) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              style: contractSecondaryButtonStyle(context),
              onPressed: _pickingFile
                  ? null
                  : () => _pickFiles(principal: false),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Agregar complementarios'),
            ),
          ),
        ],
        if (_fileError != null && !readOnly) ...[
          const SizedBox(height: 10),
          Text(
            _fileError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    ),
  );

  Widget _followUp() => _RecordSection(
    title: _followUpLabel,
    icon: Icons.fact_check_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RecordFields(
          children: [
            _option(
              'Estatus del proceso',
              _draft.status,
              () => _pickOption(
                'Estatus del proceso',
                documentalProcessStatuses,
                _draft.status,
                (v) => _draft.status = v,
              ),
              error: _validate && _draft.status == null
                  ? 'Selecciona un estatus.'
                  : null,
            ),
            _option(
              'Prioridad',
              _draft.priority,
              () => _pickOption(
                'Prioridad',
                documentalPriorities,
                _draft.priority,
                (v) => _draft.priority = v,
              ),
              error: _validate && _draft.priority == null
                  ? 'Selecciona una prioridad.'
                  : null,
            ),
            if (_tracksProgress)
              _text(
                'Avance (%)',
                _draft.progressPercentage?.toString() ?? '',
                (value) => _draft.progressPercentage = int.tryParse(value),
                percentage: true,
                focusNode: _progressFocus,
                error: _validate ? _draft.progressError : null,
              ),
          ],
        ),
        if (_isAudit) ...[
          const SizedBox(height: 12),
          _option(
            'Resultado',
            _draft.auditResult.isEmpty ? null : _draft.auditResult,
            () => _pickOptional(
              'Resultado',
              documentalAuditResults,
              _draft.auditResult,
              (v) => _draft.auditResult = v,
            ),
            hint: 'Sin resultado',
          ),
          const SizedBox(height: 12),
          _text(
            'Hallazgos',
            _draft.auditFindings,
            (v) => _draft.auditFindings = v,
            multiline: true,
          ),
        ],
        const SizedBox(height: 12),
        _text(
          _nextActionLabel,
          _draft.nextAction,
          (v) => _draft.nextAction = v,
          multiline: _isAudit,
        ),
        const SizedBox(height: 12),
        _text(
          'Observaciones',
          _draft.observations,
          (v) => _draft.observations = v,
          multiline: true,
        ),
      ],
    ),
  );

  Widget _detail() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        _draft.title.trim(),
        style: TextStyle(
          color: AreaThemeScope.of(context).onGlass,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          DocumentalBadge(_draft.documentType!),
          if (_draft.status != null) DocumentalBadge(_draft.status!),
          DocumentalUrgencyBadge(
            documentalUrgency(
              _draft.status,
              _draft.expirationDate,
              widget.metadata.today,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _RecordSection(
        title: 'Datos generales',
        icon: Icons.description_outlined,
        child: _RecordFields(
          children: [
            _info(_typeLabel, _draft.documentType),
            _info(_referenceLabel, _draft.reference),
            if (_isContract) _info('Contraparte', _draft.counterpartyName),
            _info(_authorityLabel, _draft.authority),
            _info('Área / departamento', _draft.area),
            _info(
              'Responsable interno',
              widget.metadata.responsibleName(_draft.responsibleId),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      if (_isInsurance) ...[
        _RecordSection(
          title: 'Seguro',
          icon: Icons.verified_user_outlined,
          child: _RecordFields(
            children: [
              _info('Bien, persona o unidad asegurada', _draft.insuredSubject),
              _info('Cobertura', _draft.coverageDescription),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
      if (_isPersonnel) ...[
        _RecordSection(
          title: 'Personal',
          icon: Icons.badge_outlined,
          child: _info(
            'Trabajador relacionado',
            _draft.relatedEmployeeName.isEmpty
                ? 'Sin trabajador específico'
                : _draft.relatedEmployeeName,
          ),
        ),
        const SizedBox(height: 10),
      ],
      if (_isVehicle) ...[
        _RecordSection(
          title: 'Vehículos',
          icon: Icons.local_shipping_outlined,
          child: _info(
            'Unidad relacionada',
            _draft.vehicleLabel.isEmpty
                ? 'Sin unidad específica'
                : _draft.vehicleLabel,
          ),
        ),
        const SizedBox(height: 10),
      ],
      if (_isEnvironment) ...[
        _RecordSection(
          title: 'Medio Ambiente',
          icon: Icons.eco_outlined,
          child: _RecordFields(
            children: [
              _info('Número de autorización', _draft.authorizationNumber),
              _info('Instalación relacionada', _draft.installationName),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
      if (_isMaintenance) ...[
        _RecordSection(
          title: 'Mantenimiento',
          icon: Icons.build_circle_outlined,
          child: _RecordFields(
            children: [
              _info(
                'Equipo / instalación / alcance',
                _draft.maintenanceSubject,
              ),
              _info(_providerLabel, _draft.providerName),
              _info('Periodicidad', _draft.periodicity),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
      if (_isSafety) ...[
        _RecordSection(
          title: 'Seguridad e Higiene',
          icon: Icons.health_and_safety_outlined,
          child: _RecordFields(
            children: [
              _info('Trabajador relacionado', _draft.relatedEmployeeName),
              _info('Tipo de estudio', _draft.studyType),
              _info('Proveedor / capacitador', _draft.providerName),
              _info('Periodicidad', _draft.periodicity),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
      _RecordSection(
        title: _validityLabel,
        icon: Icons.event_outlined,
        child: _RecordFields(
          children: [
            if (_hasSchedule) ...[
              _info('Fecha programada', _dateLabel(_draft.scheduledDate)),
              _info('Fecha realizada', _dateLabel(_draft.performedDate)),
            ],
            if (_isContract)
              _info('Fecha de firma', _dateLabel(_draft.signatureDate))
            else
              _info('Fecha de emisión', _dateLabel(_draft.issueDate)),
            _info(_startLabel, _dateLabel(_draft.startDate)),
            _info(
              _endLabel,
              _draft.hasExpiration
                  ? _dateLabel(_draft.expirationDate)
                  : 'Sin vencimiento',
            ),
            if (_hasRenewal) ...[
              _info(
                'Renovación',
                _draft.renewalType.isEmpty
                    ? 'Sin especificar'
                    : _draft.renewalType,
              ),
              _info('Fecha de renovación', _dateLabel(_draft.renewalDate)),
              _info('Condiciones de renovación', _draft.renewalNotes),
            ],
            _info(
              'Días restantes',
              _draft.expirationDate == null
                  ? '—'
                  : '${documentalDaysRemaining(_draft.expirationDate!, widget.metadata.today)}',
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      _documents(readOnly: true),
      const SizedBox(height: 10),
      _RecordSection(
        title: _followUpLabel,
        icon: Icons.fact_check_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RecordFields(
              children: [
                _info('Estatus del proceso', _draft.status),
                _info('Prioridad', _draft.priority),
                if (_tracksProgress)
                  DocumentalProgress(_draft.progressPercentage!),
              ],
            ),
            const SizedBox(height: 12),
            if (_isAudit) ...[
              _info(
                'Resultado',
                _draft.auditResult.isEmpty
                    ? 'Sin resultado'
                    : _draft.auditResult,
              ),
              const SizedBox(height: 12),
              _info('Hallazgos', _draft.auditFindings),
              const SizedBox(height: 12),
            ],
            _info(_nextActionLabel, _draft.nextAction),
            const SizedBox(height: 12),
            _info('Observaciones', _draft.observations),
          ],
        ),
      ),
      const SizedBox(height: 10),
      _RecordSection(
        title: 'Historial',
        icon: Icons.history_rounded,
        child: _history(),
      ),
    ],
  );

  String? _dateLabel(DateTime? date) => date == null
      ? null
      : MaterialLocalizations.of(context).formatCompactDate(date);

  Widget _label(String label) => Text(
    label,
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      color: AreaThemeScope.of(context).primarySoft,
    ),
  );

  Widget _text(
    String label,
    String value,
    ValueChanged<String> onChanged, {
    bool multiline = false,
    bool autofocus = false,
    bool percentage = false,
    String? error,
    FocusNode? focusNode,
  }) => TextFormField(
    key: ValueKey(label),
    initialValue: value,
    focusNode: focusNode,
    autofocus: autofocus,
    minLines: multiline ? 3 : 1,
    maxLines: multiline ? 5 : 1,
    keyboardType: percentage ? TextInputType.number : null,
    inputFormatters: percentage
        ? [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ]
        : null,
    textInputAction: multiline ? TextInputAction.newline : TextInputAction.done,
    onFieldSubmitted: multiline ? null : (_) => _showPreview(),
    onChanged: (value) {
      onChanged(value);
      _draft.modified = true;
      if (_validate) setState(() {});
    },
    decoration: InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      suffixText: percentage ? '%' : null,
      errorText: error,
      errorMaxLines: 3,
    ),
  );

  Widget _option(
    String label,
    String? value,
    VoidCallback? onTap, {
    String hint = 'Seleccionar',
    String? error,
  }) => _RecordPickerField(
    label: label,
    value: value,
    hint: hint,
    onTap: onTap,
    error: error,
  );

  Widget _date(
    String label,
    DateTime? value,
    ValueChanged<DateTime?> onSelected, {
    String? error,
  }) => _RecordPickerField(
    label: label,
    value: _dateLabel(value),
    hint: 'Sin fecha',
    error: error,
    icon: Icons.calendar_month_rounded,
    onTap: () => _pickDate(label, value, onSelected),
    onClear: value == null
        ? null
        : () => setState(() {
            onSelected(null);
            _draft.modified = true;
          }),
  );

  Widget _info(String label, String? value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label(label),
      const SizedBox(height: 6),
      SelectableText(value == null || value.trim().isEmpty ? '—' : value),
    ],
  );

  Widget _file(PlatformFile file, VoidCallback? onRemove) {
    final tokens = AreaThemeScope.of(context);
    final size = file.size >= 1024 * 1024
        ? '${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${(file.size / 1024).ceil()} KB';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.fieldSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.border.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            color: tokens.primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '$size · Seleccionado, sin subir',
                  style: TextStyle(fontSize: 12, color: tokens.primarySoft),
                ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              tooltip: 'Quitar ${file.name}',
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
        ],
      ),
    );
  }
}

/// Section composition cloned from Mantenimiento._sectionWithIcon;
/// tokens replace its fixed colors, and content determines the height.
class _RecordSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _RecordSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.glassSurface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.border.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: tokens.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _RecordFields extends StatelessWidget {
  final List<Widget> children;
  const _RecordFields({required this.children});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 620 ? 2 : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 16,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

/// InputDecorator keeps picker/text fields aligned; InkWell provides native
/// focus, hover, Enter and Space without borrowing the editable-grid capsule.
class _RecordPickerField extends StatelessWidget {
  final String label;
  final String? value;
  final String hint;
  final String? error;
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  const _RecordPickerField({
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
    this.error,
    this.icon = Icons.expand_more_rounded,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    key: ValueKey('documental-picker-$label'),
    button: true,
    label: label,
    enabled: onTap != null,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          enabled: onTap != null,
          errorText: error,
          errorMaxLines: 3,
          suffixIcon: onClear == null
              ? Icon(icon, size: 20)
              : IconButton(
                  tooltip: 'Limpiar $label',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
        ),
        child: Text(
          value ?? hint,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: value == null
                ? AreaThemeScope.of(context).onGlass.withValues(alpha: 0.6)
                : AreaThemeScope.of(context).onGlass,
          ),
        ),
      ),
    ),
  );
}
