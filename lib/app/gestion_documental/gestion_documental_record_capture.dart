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
  DocumentalCategory get _category =>
      documentalCategories.firstWhere((c) => c.key == widget.kind.key);
  String get _titleLabel =>
      _isProcedure ? 'Trámite / expediente' : 'Nombre del documento';
  String get _typeLabel =>
      _isProcedure ? 'Tipo de gestión' : 'Tipo de documento';
  String get _authorityLabel =>
      _isProcedure ? 'Dependencia' : 'Notaría / autoridad';
  String get _referenceLabel =>
      _isProcedure ? 'Folio / referencia' : 'Folio / escritura / referencia';
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
                    'next_action': 'Próxima acción',
                  }.entries)
                    _info(entry.value, h.record.data[entry.key]?.toString()),
                  _info(
                    'Responsable',
                    widget.metadata.responsibleName(h.record.responsibleId),
                  ),
                  if (_isProcedure) _info('Avance', '${h.record.progress}%'),
                  _info('Emisión', _dateLabel(h.record.date('issue_date'))),
                  _info(
                    'Inicio de vigencia',
                    _dateLabel(h.record.date('start_date')),
                  ),
                  _info(
                    'Vencimiento',
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
          _draft.responsibleId == null) {
        _section = 0;
      } else if (_draft.expirationError != null) {
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
                                  ? (_isProcedure
                                        ? 'Nuevo trámite'
                                        : 'Nuevo documento legal')
                                  : (_isProcedure
                                        ? 'Editar trámite'
                                        : 'Editar documento legal'),
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
                        for (final entry in const [
                          'Datos generales',
                          'Vigencia',
                          'Documentación',
                          'Seguimiento',
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
            _text(
              _authorityLabel,
              _draft.authority,
              (v) => _draft.authority = v,
            ),
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
          ],
        ),
      ],
    ),
  );

  Widget _validity() => _RecordSection(
    title: 'Vigencia',
    icon: Icons.event_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RecordFields(
          children: [
            _date(
              'Fecha de emisión',
              _draft.issueDate,
              (v) => _draft.issueDate = v,
            ),
            _date(
              'Inicio de vigencia',
              _draft.startDate,
              (v) => _draft.startDate = v,
            ),
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
            'Fecha de vencimiento',
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
      ],
    ),
  );

  Widget _documents({bool readOnly = false}) => _RecordSection(
    title: 'Documentación',
    icon: Icons.attach_file_rounded,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('Documento principal'),
        const SizedBox(height: 8),
        if (_draft.principal == null &&
            !_draft.savedFiles.any((f) => f.role == 'principal'))
          const Text('Sin archivo principal seleccionado.')
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
    title: 'Seguimiento',
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
            if (_isProcedure)
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
        const SizedBox(height: 12),
        _text(
          'Próxima acción',
          _draft.nextAction,
          (v) => _draft.nextAction = v,
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
      _RecordSection(
        title: 'Vigencia',
        icon: Icons.event_outlined,
        child: _RecordFields(
          children: [
            _info('Fecha de emisión', _dateLabel(_draft.issueDate)),
            _info('Inicio de vigencia', _dateLabel(_draft.startDate)),
            _info(
              'Fecha de vencimiento',
              _draft.hasExpiration
                  ? _dateLabel(_draft.expirationDate)
                  : 'Sin vencimiento',
            ),
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
        title: 'Seguimiento',
        icon: Icons.fact_check_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RecordFields(
              children: [
                _info('Estatus del proceso', _draft.status),
                _info('Prioridad', _draft.priority),
                if (_isProcedure)
                  DocumentalProgress(_draft.progressPercentage!),
              ],
            ),
            const SizedBox(height: 12),
            _info('Próxima acción', _draft.nextAction),
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
