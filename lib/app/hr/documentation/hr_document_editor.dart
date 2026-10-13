part of '../human_resources_documentation_page.dart';

class HrDocumentEditor extends StatefulWidget {
  final HrDocument document;
  final List<Map<String, dynamic>> employees;
  final String? employeeError;
  final Future<HrDocument> Function(HrDocumentSaveOperation) onSave;
  final Future<void> Function(HrDocument) onPdf;
  final Future<HrDocumentUpload?> Function()? pickFile;
  const HrDocumentEditor({
    super.key,
    required this.document,
    this.employees = const [],
    this.employeeError,
    required this.onSave,
    required this.onPdf,
    this.pickFile,
  });
  @override
  State<HrDocumentEditor> createState() => _HrDocumentEditorState();
}

class _HrDocumentEditorState extends State<HrDocumentEditor> {
  late HrDocument _base = widget.document;
  late final _title = TextEditingController(text: _base.title);
  late final _body = TextEditingController(text: _base.body);
  late final _fields = [..._base.fields];
  late final _data = {
    for (final field in _fields)
      field.key: TextEditingController(text: _base.values[field.key] ?? ''),
  };
  late final _signatureNames = [
    for (final s in _base.signatures)
      TextEditingController(text: s['name'] ?? ''),
  ];
  late final _signatureLabels = [
    for (final s in _base.signatures)
      TextEditingController(text: s['label'] ?? ''),
  ];
  late String _date = _base.date;
  late String? _employeeId = _base.row['employee_id'] as String?;
  late bool _archived = _base.archived;
  HrDocumentUpload? _upload;
  HrDocumentSaveOperation? _operation;
  bool _busy = false, _savePdf = false;
  int _tab = 0;
  String? _error, _notice;
  bool get _locked => _busy || (_operation?.confirmationPending ?? false);
  bool get _template => _base.kind == 'template';
  bool get _uploaded => _base.kind == 'uploaded';
  @override
  void dispose() {
    for (final c in [
      _title,
      _body,
      ..._data.values,
      ..._signatureNames,
      ..._signatureLabels,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed([String? _]) {
    if (!_locked) _operation = null;
  }

  HrDocument _snapshot() => _base.copy({
    'title': _title.text.trim(),
    'document_date': _date,
    'employee_id': _template ? null : _employeeId,
    'fields': _fields.map((f) => f.toJson()).toList(),
    'data': _template
        ? <String, String>{}
        : {for (final f in _fields) f.key: _data[f.key]!.text.trim()},
    'body': _body.text.trim(),
    'archived': _archived,
    'signatures': [
      for (var i = 0; i < _signatureLabels.length; i++)
        {
          'label': _signatureLabels[i].text.trim(),
          'name': _template ? '' : _signatureNames[i].text.trim(),
        },
    ],
  });

  Future<void> _save({bool pdf = false}) async {
    if (_busy) return;
    if (_operation?.confirmationPending != true) {
      final snapshot = _snapshot();
      final errors = snapshot.validation(forPdf: pdf);
      if (_uploaded && _upload == null && snapshot.file == null) {
        errors.add('Selecciona el archivo que vas a cargar.');
      }
      if (errors.isNotEmpty) {
        setState(() => _error = errors.join('\n'));
        return;
      }
      _operation = HrDocumentSaveOperation(snapshot, upload: _upload);
      _savePdf = pdf;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    HrDocument? saved;
    try {
      saved = await widget.onSave(_operation!);
      _base = saved;
      _operation = null;
      _upload = null;
      if (_savePdf) await widget.onPdf(saved);
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e is PostgrestException) {
            // SQL error is a confirmed rollback. Keep any uploaded object for
            // retry instead of uploading another identical file.
            if (_operation?.uploadedFile != null) {
              _base = _base.copy({'file': _operation!.uploadedFile});
              _upload = null;
            }
            _operation = null;
          }
          _error = saved != null
              ? 'El documento quedó guardado. No se pudo generar o abrir el PDF: ${_hrDocError(e)}'
              : _hrDocError(e);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick() async {
    if (_locked) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      HrDocumentUpload? upload;
      if (widget.pickFile != null) {
        upload = await widget.pickFile!();
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: hrDocumentMimeTypes.keys.toList(),
          withData: false,
          dialogTitle: 'Cargar documento de RH',
        );
        if (result != null) {
          final file = result.files.single;
          if (file.size > hrDocumentFileLimit) {
            throw const FormatException(
              'El archivo debe pesar como máximo 25 MB.',
            );
          }
          final bytes =
              file.bytes ??
              (file.path == null ? null : await File(file.path!).readAsBytes());
          if (bytes == null) {
            throw StateError(
              'No se pudo leer el archivo. Selecciónalo de nuevo.',
            );
          }
          upload = HrDocumentUpload(file.name, bytes);
        }
      }
      upload?.validate();
      if (upload != null && mounted) {
        setState(() {
          _upload = upload;
          _operation = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = _hrDocError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectEmployee() async {
    final employees = [...widget.employees]
      ..sort((a, b) => '${a['nombre']}'.compareTo('${b['nombre']}'));
    final id = await showSearchablePickerDialog<String>(
      context,
      title: 'Selecciona colaborador',
      initialValue: _employeeId,
      options: [
        for (final e in employees)
          SearchablePickerOption(
            value: '${e['id']}',
            label: '${e['nombre']} · ${e['empresa'] ?? ''}',
          ),
      ],
    );
    if (id == null || !mounted) return;
    final employee = employees.firstWhere((e) => '${e['id']}' == id);
    setState(() {
      _employeeId = id;
      for (final key in ['nombre', 'empresa', 'puesto']) {
        if (_data.containsKey(key) && employee[key] != null) {
          _data[key]!.text = '${employee[key]}';
        }
      }
      _changed();
    });
  }

  Future<void> _datePicker({HrDocumentField? field}) async {
    final raw = field == null ? _date : _data[field.key]!.text;
    final initial = DateTime.tryParse(raw) ?? DateTime.now();
    final selected = await showContractDatePickerSurface(
      context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
      title: field?.label ?? 'Fecha del documento',
    );
    if (selected != null && mounted) {
      setState(() {
        if (field == null) {
          _date = hrDocumentIsoDate(selected);
        } else {
          _data[field.key]!.text = hrDocumentIsoDate(selected);
        }
        _changed();
      });
    }
  }

  Future<void> _saveTemplate() async {
    final saved = await showDialog<HrDocument>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AreaThemeScope(
        tokens: humanResourcesAreaTokens,
        child: HrDocumentEditor(
          document: _snapshot().asTemplate(),
          onSave: widget.onSave,
          onPdf: widget.onPdf,
        ),
      ),
    );
    if (saved != null && mounted) {
      setState(
        () => _notice =
            'Plantilla guardada. Continúa con los datos de este documento.',
      );
    }
  }

  Future<void> _addField() async {
    final result = await showDialog<HrDocumentField>(
      context: context,
      builder: (_) => AreaThemeScope(
        tokens: humanResourcesAreaTokens,
        child: _HrDocumentAddField(existing: _fields.map((f) => f.key).toSet()),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _fields.add(result);
        _data[result.key] = TextEditingController();
        _body.text = '${_body.text}\n\n${result.label}\n{{${result.key}}}';
        _changed();
      });
    }
  }

  Widget _textField(
    String label,
    TextEditingController controller, {
    String? keyName,
    bool multiline = false,
    int? maxLength,
  }) => TextField(
    key: keyName == null ? null : ValueKey(keyName),
    autofocus: keyName == 'document-title',
    controller: controller,
    enabled: !_locked,
    style: _hrDocText(14),
    cursorColor: humanResourcesAreaTokens.accent,
    minLines: multiline ? 3 : 1,
    maxLines: multiline ? null : 1,
    maxLength: maxLength,
    onChanged: _changed,
    onSubmitted: multiline ? null : (_) => _save(),
    decoration: contractGlassFieldDecoration(context).copyWith(
      labelText: label,
      labelStyle: _hrDocText(13, muted: true),
      alignLabelWithHint: multiline,
      counterStyle: _hrDocText(11, muted: true),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (!_busy) Navigator.of(context).pop();
        },
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
            _save(),
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () =>
            _save(),
      },
      child: ContractDialogShell(
        child: SizedBox(
          width: 1060,
          height: MediaQuery.sizeOf(context).height * .9,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _template
                                ? 'Plantilla editable'
                                : _uploaded
                                ? 'Cargar documentación'
                                : 'Llenar documento',
                            style: _hrDocText(23, strong: true),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _base.category.label,
                            style: _hrDocText(13, muted: true),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: humanResourcesAreaTokens.accent,
                      ),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _textField(
                        'Nombre del documento',
                        _title,
                        keyName: 'document-title',
                        maxLength: 240,
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      style: contractSecondaryButtonStyle(context),
                      onPressed: _locked ? null : () => _datePicker(),
                      icon: const Icon(Icons.calendar_month),
                      label: Text(hrDocumentDisplayDate(_date)),
                    ),
                  ],
                ),
                if (!_uploaded)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final entry in [
                          (0, _template ? 'Formato' : 'Datos'),
                          (1, 'Texto y firmas'),
                          (2, 'Vista previa'),
                        ])
                          ChoiceChip(
                            label: Text(entry.$2),
                            selected: _tab == entry.$1,
                            selectedColor: humanResourcesAreaTokens.accent,
                            backgroundColor:
                                humanResourcesAreaTokens.fieldSurface,
                            labelStyle: TextStyle(
                              color: _tab == entry.$1
                                  ? humanResourcesAreaTokens.primaryStrong
                                  : humanResourcesAreaTokens.onGlass,
                            ),
                            onSelected: (_) => setState(() => _tab = entry.$1),
                          ),
                      ],
                    ),
                  ),
                if (_error != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 110),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_error!, style: _hrDocText(13)),
                      ),
                    ),
                  ),
                if (_notice != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_notice!, style: _hrDocText(13, muted: true)),
                  ),
                if (_operation?.confirmationPending == true && !_busy)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'No se confirmó la respuesta del guardado. Reintenta para verificar la misma solicitud.',
                      style: _hrDocText(13),
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    key: ValueKey('editor-tab-$_tab'),
                    child: _uploaded || _tab == 0
                        ? _capture()
                        : _tab == 1
                        ? _textAndSignatures()
                        : _preview(),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (_busy)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: humanResourcesAreaTokens.accent,
                        ),
                      ),
                    if (!_template && !_uploaded)
                      TextButton.icon(
                        style: contractSecondaryButtonStyle(context),
                        onPressed: _locked ? null : _saveTemplate,
                        icon: const Icon(Icons.copy_all_outlined),
                        label: const Text('Guardar como plantilla'),
                      ),
                    TextButton(
                      style: contractSecondaryButtonStyle(context),
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    OutlinedButton.icon(
                      style: contractSecondaryButtonStyle(context),
                      onPressed: _busy ? null : () => _save(),
                      icon: const Icon(Icons.save_outlined),
                      label: Text(
                        _operation?.confirmationPending == true
                            ? 'Reintentar guardado'
                            : 'Guardar',
                      ),
                    ),
                    if (!_template && !_uploaded)
                      ElevatedButton.icon(
                        style: contractPrimaryButtonStyle(context),
                        onPressed: _locked ? null : () => _save(pdf: true),
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('Guardar y PDF'),
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

  Widget _capture() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_uploaded) ...[
        OutlinedButton.icon(
          style: contractSecondaryButtonStyle(context),
          onPressed: _locked ? null : _pick,
          icon: const Icon(Icons.upload_file),
          label: Text(
            _upload?.name ??
                _base.file?['name']?.toString() ??
                'Seleccionar archivo',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'PDF, Word, JPG o PNG · Máximo 25 MB',
          style: _hrDocText(12, muted: true),
        ),
        const SizedBox(height: 18),
      ],
      if (_template) ...[
        Text(
          'Edita el texto, los datos a llenar y las firmas. Al usar la plantilla, cada documento tendrá su propia captura.',
          style: _hrDocText(14),
        ),
        const SizedBox(height: 16),
        for (final field in _fields)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(field.label, style: _hrDocText(14)),
            subtitle: Text(
              '{{${field.key}}}',
              style: _hrDocText(12, muted: true),
            ),
            trailing: Switch(
              value: field.required,
              activeThumbColor: humanResourcesAreaTokens.accent,
              onChanged: _locked
                  ? null
                  : (value) => setState(() {
                      final index = _fields.indexOf(field);
                      _fields[index] = HrDocumentField(
                        field.key,
                        field.label,
                        type: field.type,
                        required: value,
                      );
                      _changed();
                    }),
            ),
            leading: Tooltip(
              message: field.required ? 'Obligatorio para PDF' : 'Opcional',
              child: Icon(
                field.required ? Icons.star : Icons.star_outline,
                color: humanResourcesAreaTokens.accent,
              ),
            ),
          ),
        OutlinedButton.icon(
          style: contractSecondaryButtonStyle(context),
          onPressed: _locked || _fields.length >= 60 ? null : _addField,
          icon: const Icon(Icons.add),
          label: const Text('Agregar dato'),
        ),
      ] else ...[
        if (widget.employeeError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              widget.employeeError!,
              style: _hrDocText(13, muted: true),
            ),
          ),
        if (_data.containsKey('nombre'))
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: contractSecondaryButtonStyle(context),
              onPressed: _locked || widget.employees.isEmpty
                  ? null
                  : _selectEmployee,
              icon: const Icon(Icons.person_search_outlined),
              label: const Text('Elegir colaborador'),
            ),
          ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 14,
            runSpacing: 16,
            children: [
              for (final field in _fields.where(
                (f) =>
                    !_uploaded ||
                    [
                      'nombre',
                      'empresa',
                      'puesto',
                      'observaciones',
                    ].contains(f.key),
              ))
                SizedBox(
                  width: field.type == 'multiline' || constraints.maxWidth < 600
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 14) / 2,
                  child: field.type == 'date'
                      ? TextField(
                          key: ValueKey('field-${field.key}'),
                          controller: _data[field.key],
                          enabled: !_locked,
                          readOnly: true,
                          style: _hrDocText(14),
                          onTap: () => _datePicker(field: field),
                          decoration: contractGlassFieldDecoration(context)
                              .copyWith(
                                labelText:
                                    '${field.label}${field.required ? ' *' : ''}',
                                labelStyle: _hrDocText(13, muted: true),
                                suffixIcon: Icon(
                                  Icons.calendar_month,
                                  color: humanResourcesAreaTokens.accent,
                                ),
                              ),
                        )
                      : _textField(
                          '${field.label}${field.required && !_uploaded ? ' *' : ''}',
                          _data[field.key]!,
                          keyName: 'field-${field.key}',
                          multiline: field.type == 'multiline',
                        ),
                ),
            ],
          ),
        ),
      ],
      if (_base.revision > 0)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Archivado', style: _hrDocText(14)),
            subtitle: Text(
              'Conserva el documento en la pestaña Archivados.',
              style: _hrDocText(12, muted: true),
            ),
            value: _archived,
            activeThumbColor: humanResourcesAreaTokens.accent,
            onChanged: _locked
                ? null
                : (value) => setState(() {
                    _archived = value;
                    _changed();
                  }),
          ),
        ),
    ],
  );

  Widget _textAndSignatures() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Los datos entre {{ }} se sustituyen al imprimir. Puedes ajustar todo el texto.',
        style: _hrDocText(13, muted: true),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final key in ['fecha', ..._fields.map((f) => f.key)])
            ActionChip(
              backgroundColor: humanResourcesAreaTokens.fieldSurface,
              labelStyle: _hrDocText(12, muted: true),
              label: Text('{{$key}}'),
              onPressed: _locked
                  ? null
                  : () {
                      final selection = _body.selection;
                      final start = selection.isValid
                          ? selection.start
                          : _body.text.length;
                      final end = selection.isValid
                          ? selection.end
                          : _body.text.length;
                      final replacement = '{{$key}}';
                      _body.value = TextEditingValue(
                        text: _body.text.replaceRange(start, end, replacement),
                        selection: TextSelection.collapsed(
                          offset: start + replacement.length,
                        ),
                      );
                      _changed();
                    },
            ),
        ],
      ),
      const SizedBox(height: 14),
      _textField('Contenido', _body, keyName: 'document-body', multiline: true),
      const SizedBox(height: 22),
      Text('Firmas', style: _hrDocText(18, strong: true)),
      const SizedBox(height: 14),
      for (var i = 0; i < _signatureLabels.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _textField(
                  'Cargo / leyenda de firma',
                  _signatureLabels[i],
                  maxLength: 100,
                ),
              ),
              if (!_template) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _textField(
                    'Nombre de quien firma',
                    _signatureNames[i],
                    maxLength: 240,
                  ),
                ),
              ],
            ],
          ),
        ),
    ],
  );

  Widget _preview() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(_title.text, style: _hrDocText(22, strong: true)),
      const SizedBox(height: 20),
      SelectableText(
        _snapshot().renderedBody(),
        style: _hrDocText(15).copyWith(height: 1.6),
      ),
      const SizedBox(height: 28),
      for (var i = 0; i < _signatureLabels.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Text(
            '${_signatureNames[i].text}\n${_signatureLabels[i].text}',
            style: _hrDocText(14, muted: true),
          ),
        ),
    ],
  );
}

class _HrDocumentAddField extends StatefulWidget {
  final Set<String> existing;
  const _HrDocumentAddField({required this.existing});
  @override
  State<_HrDocumentAddField> createState() => _HrDocumentAddFieldState();
}

class _HrDocumentAddFieldState extends State<_HrDocumentAddField> {
  final _label = TextEditingController();
  String _type = 'text';
  String? _error;
  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _add() {
    final label = _label.text.trim();
    if (label.isEmpty) {
      setState(() => _error = 'Escribe el nombre del dato.');
      return;
    }
    var n = 1;
    while (widget.existing.contains('dato_$n')) {
      n++;
    }
    Navigator.of(context).pop(HrDocumentField('dato_$n', label, type: _type));
  }

  @override
  Widget build(BuildContext context) => ContractDialogShell(
    child: SizedBox(
      width: 480,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Agregar dato a la plantilla',
              style: _hrDocText(20, strong: true),
            ),
            const SizedBox(height: 20),
            TextField(
              autofocus: true,
              controller: _label,
              maxLength: 100,
              style: _hrDocText(14),
              onSubmitted: (_) => _add(),
              decoration: contractGlassFieldDecoration(
                context,
                hintText: 'Nombre del dato',
              ).copyWith(errorText: _error),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              dropdownColor: humanResourcesAreaTokens.fieldSurface,
              style: _hrDocText(14),
              decoration: contractGlassFieldDecoration(context),
              items: [
                for (final type in [
                  ('date', 'Fecha'),
                  ('money', 'Monto'),
                  ('number', 'Número'),
                  ('text', 'Texto'),
                  ('multiline', 'Texto largo'),
                ])
                  DropdownMenuItem(value: type.$1, child: Text(type.$2)),
              ],
              onChanged: (value) => setState(() => _type = value!),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              children: [
                TextButton(
                  style: contractSecondaryButtonStyle(context),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: contractPrimaryButtonStyle(context),
                  onPressed: _add,
                  child: const Text('Agregar'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
