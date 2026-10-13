part of '../human_resources_documentation_page.dart';

class HrDocumentWorkspace extends StatefulWidget {
  final List<HrDocument> records;
  final Future<void> Function(HrDocument)? onEdit;
  final Future<void> Function(HrDocument) onDownload, onOpenFile;
  final HrDocumentCategory? initialCategory;
  const HrDocumentWorkspace({
    super.key,
    required this.records,
    this.onEdit,
    required this.onDownload,
    required this.onOpenFile,
    this.initialCategory,
  });
  @override
  State<HrDocumentWorkspace> createState() => _HrDocumentWorkspaceState();
}

class _HrDocumentWorkspaceState extends State<HrDocumentWorkspace> {
  late HrDocumentCategory? _category = widget.initialCategory;
  final _search = TextEditingController();
  final _librarySearch = TextEditingController();
  final _libraryScroll = ScrollController();
  String? _libraryGroup;
  final _listFocus = FocusNode(debugLabel: 'Documentos RH');
  final _keys = <String, GlobalKey>{};
  String? _selected;
  String _filter = 'Documentos';
  @override
  void dispose() {
    _search.dispose();
    _librarySearch.dispose();
    _libraryScroll.dispose();
    _listFocus.dispose();
    super.dispose();
  }

  void _select(HrDocument record) {
    setState(() => _selected = record.id);
    _listFocus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _keys[record.id]?.currentContext;
      if (mounted && context != null) {
        Scrollable.ensureVisible(context, alignment: .5);
      }
    });
  }

  Future<void> _create() async {
    final category = _category!;
    final templates =
        widget.records
            .where(
              (r) =>
                  r.category == category && r.kind == 'template' && !r.archived,
            )
            .toList()
          ..sort((a, b) => a.title.compareTo(b.title));
    HrDocument draft = hrDocumentBase(category, DateTime.now());
    if (templates.isNotEmpty) {
      final chosen = await showSearchablePickerDialog<String>(
        context,
        title: 'Selecciona una plantilla',
        options: [
          const SearchablePickerOption(value: 'base', label: 'Formato inicial'),
          for (final t in templates)
            SearchablePickerOption(value: t.id, label: t.title),
        ],
      );
      if (chosen == null || !mounted) return;
      if (chosen != 'base') {
        draft = templates
            .firstWhere((t) => t.id == chosen)
            .instantiate(DateTime.now());
      }
    }
    await widget.onEdit?.call(draft);
  }

  @override
  Widget build(BuildContext context) {
    if (_category == null) return _home();
    final query = _search.text.toLowerCase().trim();
    final records =
        widget.records
            .where(
              (r) =>
                  r.category == _category &&
                  (_filter == 'Archivados'
                      ? r.archived
                      : !r.archived &&
                            (r.kind == 'template') ==
                                (_filter == 'Plantillas')) &&
                  '${r.title} ${r.values.values.join(' ')} ${r.folio} ${r.file?['name'] ?? ''}'
                      .toLowerCase()
                      .contains(query),
            )
            .toList()
          ..sort((a, b) {
            final date = b.date.compareTo(a.date);
            return date == 0 ? a.id.compareTo(b.id) : date;
          });
    final selected =
        records.where((r) => r.id == _selected).firstOrNull ??
        records.firstOrNull;
    return WorkflowMasterDetailShell(
      masterFlex: 2,
      detailFlex: 3,
      topBar: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            style: contractSecondaryButtonStyle(context),
            onPressed: () => setState(() {
              _category = null;
              _selected = null;
              _search.clear();
              _filter = 'Documentos';
            }),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Documentación RH'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(_category!.label, style: _hrDocText(24, strong: true)),
              ElevatedButton.icon(
                style: contractPrimaryButtonStyle(context),
                onPressed: widget.onEdit == null ? null : _create,
                icon: const Icon(Icons.edit_document),
                label: const Text('Llenar documento'),
              ),
              OutlinedButton.icon(
                style: contractSecondaryButtonStyle(context),
                onPressed: widget.onEdit == null
                    ? null
                    : () => widget.onEdit!(
                        hrDocumentBase(
                          _category!,
                          DateTime.now(),
                          kind: 'uploaded',
                        ),
                      ),
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Cargar archivo'),
              ),
            ],
          ),
        ],
      ),
      master: ContractGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _search,
              style: _hrDocText(14),
              onChanged: (_) => setState(() {}),
              decoration: contractGlassFieldDecoration(
                context,
                hintText: 'Buscar nombre, empresa o documento',
                prefixIcon: Icon(
                  Icons.search,
                  color: humanResourcesAreaTokens.accent,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final filter in ['Documentos', 'Plantillas', 'Archivados'])
                  ChoiceChip(
                    label: Text(filter),
                    selected: _filter == filter,
                    selectedColor: humanResourcesAreaTokens.accent,
                    backgroundColor: humanResourcesAreaTokens.fieldSurface,
                    labelStyle: TextStyle(
                      color: _filter == filter
                          ? humanResourcesAreaTokens.primaryStrong
                          : humanResourcesAreaTokens.onGlass,
                    ),
                    onSelected: (_) => setState(() {
                      _filter = filter;
                      _selected = null;
                    }),
                  ),
              ],
            ),
            if (_filter == 'Plantillas')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TextButton.icon(
                  style: contractSecondaryButtonStyle(context),
                  onPressed: widget.onEdit == null
                      ? null
                      : () => widget.onEdit!(
                          hrDocumentBase(
                            _category!,
                            DateTime.now(),
                            kind: 'template',
                          ),
                        ),
                  icon: const Icon(Icons.add),
                  label: const Text('Nueva plantilla'),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              '${records.length} registro(s)',
              style: _hrDocText(12, muted: true),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: records.isEmpty
                  ? Center(
                      child: Text(
                        query.isEmpty
                            ? 'Aún no hay ${_filter.toLowerCase()} en esta sección.'
                            : 'No hay coincidencias.',
                        textAlign: TextAlign.center,
                        style: _hrDocText(14, muted: true),
                      ),
                    )
                  : Focus(
                      focusNode: _listFocus,
                      onKeyEvent: (_, event) {
                        if (event is! KeyDownEvent) {
                          return KeyEventResult.ignored;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                            event.logicalKey == LogicalKeyboardKey.arrowUp) {
                          final index = records.indexWhere(
                            (r) => r.id == selected?.id,
                          );
                          final next =
                              (index +
                                      (event.logicalKey ==
                                              LogicalKeyboardKey.arrowDown
                                          ? 1
                                          : -1))
                                  .clamp(0, records.length - 1);
                          _select(records[next]);
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.enter &&
                            selected != null &&
                            widget.onEdit != null) {
                          widget.onEdit!(selected);
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: ListView.builder(
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          final record = records[index];
                          final active = selected?.id == record.id;
                          return Padding(
                            key: _keys.putIfAbsent(record.id, GlobalKey.new),
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: active
                                  ? humanResourcesAreaTokens.surfaceTint
                                        .withValues(alpha: .45)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: ListTile(
                                key: ValueKey('document-${record.id}'),
                                selected: active,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                onTap: () => _select(record),
                                title: Text(
                                  record.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: _hrDocText(15, strong: true),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Text(
                                    '${record.values['nombre'] ?? record.values['empresa'] ?? record.kindLabel}\n${hrDocumentDisplayDate(record.date)} · ${record.kindLabel}',
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: _hrDocText(12, muted: true),
                                  ),
                                ),
                                trailing: Icon(
                                  record.kind == 'uploaded'
                                      ? Icons.attach_file
                                      : record.kind == 'template'
                                      ? Icons.description_outlined
                                      : Icons.article_outlined,
                                  color: humanResourcesAreaTokens.accent,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      detail: ContractGlassCard(
        child: selected == null
            ? Center(
                child: Text(
                  'Llena un documento o carga un archivo para comenzar.',
                  textAlign: TextAlign.center,
                  style: _hrDocText(16, muted: true),
                ),
              )
            : _detail(selected),
      ),
    );
  }

  Widget _detail(HrDocument record) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(record.title, style: _hrDocText(21, strong: true)),
      const SizedBox(height: 6),
      Text(
        '${record.folio} · ${record.kindLabel} · Versión ${record.revision}',
        style: _hrDocText(12, muted: true),
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            style: contractSecondaryButtonStyle(context),
            onPressed: widget.onEdit == null
                ? null
                : () => widget.onEdit!(record),
            icon: const Icon(Icons.edit_outlined),
            label: Text(
              record.kind == 'template' ? 'Editar plantilla' : 'Editar datos',
            ),
          ),
          if (record.kind == 'template')
            ElevatedButton.icon(
              style: contractPrimaryButtonStyle(context),
              onPressed: widget.onEdit == null || record.archived
                  ? null
                  : () => widget.onEdit!(record.instantiate(DateTime.now())),
              icon: const Icon(Icons.note_add_outlined),
              label: const Text('Usar plantilla'),
            )
          else
            ElevatedButton.icon(
              style: contractPrimaryButtonStyle(context),
              onPressed: () => widget.onDownload(record),
              icon: Icon(
                record.kind == 'generated'
                    ? Icons.print_outlined
                    : Icons.download_rounded,
              ),
              label: Text(
                record.kind == 'generated'
                    ? 'PDF / Imprimir'
                    : 'Descargar archivo',
              ),
            ),
          if (record.kind == 'uploaded')
            TextButton.icon(
              style: contractSecondaryButtonStyle(context),
              onPressed: () => widget.onOpenFile(record),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Abrir archivo'),
            ),
        ],
      ),
      const SizedBox(height: 16),
      Expanded(
        child: SingleChildScrollView(
          child: SelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (record.kind == 'uploaded') ...[
                  Icon(
                    Icons.upload_file_rounded,
                    size: 56,
                    color: humanResourcesAreaTokens.accent,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    record.file?['name']?.toString() ?? '',
                    style: _hrDocText(18, strong: true),
                  ),
                  const SizedBox(height: 18),
                  for (final field in record.fields.where(
                    (f) => (record.values[f.key] ?? '').isNotEmpty,
                  ))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        '${field.label}: ${record.values[field.key]}',
                        style: _hrDocText(14),
                      ),
                    ),
                ] else ...[
                  Text(
                    record.kind == 'template'
                        ? record.body
                        : record.renderedBody(),
                    style: _hrDocText(15).copyWith(height: 1.65),
                  ),
                  if (record.signatures.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Text('Firmas', style: _hrDocText(14, strong: true)),
                    for (final signature in record.signatures)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${signature['label']}: ${signature['name'] ?? ''}',
                          style: _hrDocText(14, muted: true),
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Widget _home() => _HrDocumentLibrary(
    records: widget.records,
    search: _librarySearch,
    scrollController: _libraryScroll,
    group: _libraryGroup,
    onSearchChanged: () => setState(() {}),
    onGroupChanged: (group) => setState(() => _libraryGroup = group),
    onOpen: (category) => setState(() => _category = category),
  );
}

IconData _hrDocCategoryIcon(HrDocumentCategory category) => switch (category) {
  HrDocumentCategory.reglamento => Icons.rule_rounded,
  HrDocumentCategory.manual => Icons.menu_book_outlined,
  HrDocumentCategory.comisiones => Icons.percent_rounded,
  HrDocumentCategory.telefono => Icons.phone_android,
  HrDocumentCategory.laptop => Icons.laptop,
  HrDocumentCategory.unidad => Icons.local_shipping_outlined,
  HrDocumentCategory.vacaciones => Icons.beach_access_outlined,
  HrDocumentCategory.finiquito => Icons.assignment_outlined,
  HrDocumentCategory.renuncia ||
  HrDocumentCategory.recomendacion => Icons.mail_outline,
  HrDocumentCategory.acta => Icons.fact_check_outlined,
  HrDocumentCategory.otros => Icons.folder_open,
};
