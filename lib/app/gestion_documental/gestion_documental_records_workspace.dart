import 'dart:async';

import 'package:flutter/material.dart';
import '../shared/archetypes/auxiliary_surfaces/searchable_picker.dart';
import '../shared/archetypes/grid_editable/grid_keyboard_shell.dart';
import '../shared/archetypes/grid_editable/grid_navigation_controller.dart';
import '../shared/archetypes/grid_editable/grid_selection_controller.dart';
import '../shared/archetypes/workflow_master_detail/workflow_refresh_controller.dart';
import '../shared/archetypes/workflow_master_detail/workflow_item_context_menu.dart';
import '../shared/ui_contract_core/dialogs/contract_menu_surface.dart';
import '../shared/ui_contract_core/refresh/lifecycle_refresh_scope.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import 'gestion_documental_record_capture.dart';
import 'gestion_documental_catalog.dart';
import 'gestion_documental_record_draft.dart';
import 'gestion_documental_records.dart';
import 'gestion_documental_store.dart';
import 'gestion_documental_widgets.dart';

/// Workflow: Mantenimiento's list + editable detail. The list is read-only;
/// edits are atomic record/version saves in the detail, never partial cell writes.
/// Keyboard/selection use Entradas y Salidas's shared controllers. Refresh is
/// realtime + resume, deferred while a detail is open, plus civil-day rollover.
class DocumentalRecordsWorkspace extends StatefulWidget {
  final VoidCallback onBack;
  final DocumentalRecordKind kind;
  const DocumentalRecordsWorkspace({
    super.key,
    required this.onBack,
    this.kind = DocumentalRecordKind.legal,
  });
  @override
  State<DocumentalRecordsWorkspace> createState() =>
      _DocumentalRecordsWorkspaceState();
}

class _DocumentalRecordsWorkspaceState
    extends State<DocumentalRecordsWorkspace> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _gridFocus = FocusNode();
  final _navigation = GridNavigationController();
  final _selection = GridSelectionController();
  final _refresh = WorkflowRefreshController();
  final _rowKeys = <String, GlobalKey>{};
  DocumentalRepository? _repository;
  DocumentalContext? _metadata;
  DocumentalResultPage _result = const DocumentalResultPage([], 0);
  StreamSubscription<void>? _subscription;
  Timer? _searchTimer, _midnight;
  String? _error, _status, _type, _responsible, _urgency, _priority;
  bool get _isProcedure => widget.kind == DocumentalRecordKind.procedures;
  DocumentalCategory get _category =>
      documentalCategories.firstWhere((c) => c.key == widget.kind.key);
  List<(String, int)> get _columns => _isProcedure
      ? [
          ('Trámite', 22),
          ('Dependencia', 16),
          ('Responsable', 18),
          ('Vencimiento', 13),
          ('Días', 7),
          ('Prioridad', 8),
          ('Estado', 16),
          ('Avance', 8),
        ]
      : [
          ('Documento', 3),
          ('Tipo', 2),
          ('Responsable', 2),
          ('Vencimiento', 2),
          ('Vigencia', 2),
        ];
  String _sort = 'recent';
  int _page = 0;
  bool _loading = true, _detailOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_repository != null) return;
    _repository = DocumentalRepositoryScope.of(context);
    _subscription = _repository!.changes.listen((_) => _requestRefresh());
    _selection.addListener(_selectionChanged);
    unawaited(_requestRefresh());
  }

  void _selectionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _searchTimer?.cancel();
    _midnight?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    _gridFocus.dispose();
    _navigation.dispose();
    _selection.dispose();
    super.dispose();
  }

  Future<void> _requestRefresh() => _refresh.requestRefresh(_load);
  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final values = await Future.wait<Object>([
        _repository!.loadContext(),
        _repository!.loadPage(
          DocumentalQuery(
            kind: widget.kind,
            priority: _priority,
            search: _search.text.trim(),
            status: _status,
            type: _type,
            responsibleId: _responsible,
            urgency: _urgency,
            page: _page,
            sort: _sort,
          ),
        ),
      ]);
      if (!mounted) return;
      final metadata = values[0] as DocumentalContext;
      final result = values[1] as DocumentalResultPage;
      final anchor = _selection.anchorIndex;
      final anchorId = anchor != null && anchor < _result.records.length
          ? _result.records[anchor].id
          : null;
      setState(() {
        _metadata = metadata;
        _result = result;
        _error = null;
      });
      _rowKeys.removeWhere((id, _) => !result.records.any((r) => r.id == id));
      _selection.selectedIds.removeWhere(
        (id) => !result.records.any((r) => r.id == id),
      );
      final nextAnchor = result.records.indexWhere((r) => r.id == anchorId);
      _selection.anchorIndex = nextAnchor < 0 ? null : nextAnchor;
      _navigation.configure(
        insertColumnCount: 1,
        gridColumnCount: 1,
        rowCount: result.records.length,
      );
      _midnight?.cancel();
      _midnight = Timer(metadata.untilMidnight, () => _requestRefresh());
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = documentalErrorMessage(error);
          _metadata = null;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filterChanged() {
    _page = 0;
    unawaited(_requestRefresh());
  }

  Future<void> _filter(
    String title,
    List<SearchablePickerOption<String>> options,
    String? current,
    ValueChanged<String?> update,
  ) async {
    final value = await showSearchablePickerDialog<String>(
      context,
      title: title,
      initialValue: current ?? '',
      options: [
        const SearchablePickerOption(value: '', label: 'Todos'),
        ...options,
      ],
    );
    if (value == null || !mounted) return;
    setState(() => update(value.isEmpty ? null : value));
    _filterChanged();
  }

  List<SearchablePickerOption<String>> _options(Iterable<String> values) => [
    for (final value in (values.toList()..sort()))
      SearchablePickerOption(value: value, label: value),
  ];

  Future<void> _open({DocumentalRecord? record, bool followUp = false}) async {
    if (_detailOpen || _metadata == null) return;
    _detailOpen = true;
    _refresh.editGuard.beginEditing();
    try {
      final detail = record == null
          ? null
          : await _repository!.loadDetail(record.id);
      if (!mounted) return;
      await showDocumentalRecordCapture(
        context,
        repository: _repository!,
        metadata: _metadata!,
        detail: detail,
        kind: widget.kind,
        startWithFollowUp: followUp,
      );
    } catch (error) {
      if (mounted) setState(() => _error = documentalErrorMessage(error));
    } finally {
      _detailOpen = false;
      _refresh.editGuard.endEditing();
      if (mounted) {
        if (_refresh.realtime.queuedWhileEditing) {
          await _refresh.flushPending(_load);
        } else {
          await _requestRefresh();
        }
      }
    }
  }

  void _openSelected({bool followUp = false}) {
    if (_selection.selectedIds.length != 1) return;
    final record = _result.records
        .where((r) => _selection.isSelected(r.id))
        .firstOrNull;
    if (record != null) unawaited(_open(record: record, followUp: followUp));
  }

  Future<void> _contextMenu(
    DocumentalRecord record,
    int index,
    Offset position,
  ) async {
    if (!_selection.isSelected(record.id)) {
      _selection.selectSingle(record.id, rowIndex: index);
    }
    final action = await showWorkflowItemContextMenu<String>(
      context: context,
      globalPosition: position,
      entries: [
        ContractMenuEntry(
          value: 'open',
          label: 'Abrir expediente',
          icon: Icons.open_in_new_rounded,
          enabled: _selection.selectedIds.length == 1,
        ),
        if (_isProcedure)
          ContractMenuEntry(
            value: 'followUp',
            label: 'Actualizar seguimiento',
            icon: Icons.edit_note_rounded,
            enabled: _selection.selectedIds.length == 1,
          ),
      ],
    );
    if (action == 'open' && mounted) _openSelected();
    if (action == 'followUp' && mounted) _openSelected(followUp: true);
  }

  void _select(DocumentalRecord record, int index) {
    _gridFocus.requestFocus();
    _selection.handlePointerSelection(
      id: record.id,
      rowIndex: index,
      resolveRangeIds: (from, to) =>
          _result.records.sublist(from, to + 1).map((r) => r.id),
    );
    _navigation.focusGridCell(rowIndex: index, columnIndex: 0);
  }

  void _navigated(GridCellPosition position) {
    if (position.zone == GridNavigationZone.insertRow) {
      _searchFocus.requestFocus();
      return;
    }
    final index = position.rowIndex;
    if (index < 0 || index >= _result.records.length) return;
    final record = _result.records[index];
    _selection.selectSingle(record.id, rowIndex: index);
    final rowContext = _rowKeys[record.id]?.currentContext;
    if (rowContext != null) {
      Scrollable.ensureVisible(
        rowContext,
        duration: const Duration(milliseconds: 120),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AreaThemeScope.of(context);
    final filtered =
        _search.text.isNotEmpty ||
        _status != null ||
        _type != null ||
        _responsible != null ||
        _priority != null ||
        _urgency != null;
    return LifecycleRefreshScope(
      onResume: _requestRefresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Dashboard Gestión Documental'),
            ),
          ),
          const SizedBox(height: 8),
          DocumentalPageHeading(
            title: _category.title,
            description: _category.description,
            action: DocumentalBadge(
              _metadata == null
                  ? _category.title
                  : '${_result.total} ${_isProcedure ? (_result.total == 1 ? 'trámite' : 'trámites') : (_result.total == 1 ? 'documento' : 'documentos')}',
            ),
          ),
          const SizedBox(height: 18),
          ContractGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: constraints.maxWidth < 600
                            ? constraints.maxWidth
                            : 260,
                        child: TextField(
                          controller: _search,
                          focusNode: _searchFocus,
                          onChanged: (_) {
                            _searchTimer?.cancel();
                            _searchTimer = Timer(
                              const Duration(milliseconds: 250),
                              _filterChanged,
                            );
                          },
                          decoration: InputDecoration(
                            hintText: _isProcedure
                                ? 'Buscar trámite, folio o dependencia…'
                                : 'Buscar documento, folio o autoridad…',
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      _filterButton(
                        _type ?? 'Tipo',
                        Icons.description_outlined,
                        () => _filter(
                          _isProcedure
                              ? 'Tipo de gestión'
                              : 'Tipo de documento',
                          _options(documentalTypesFor(widget.kind)),
                          _type,
                          (v) => _type = v,
                        ),
                      ),
                      _filterButton(
                        _status ?? 'Estatus',
                        Icons.filter_list_rounded,
                        () => _filter(
                          'Estatus del registro',
                          _options(documentalProcessStatuses),
                          _status,
                          (v) => _status = v,
                        ),
                      ),
                      _filterButton(
                        _responsible == null
                            ? 'Responsable'
                            : _metadata?.responsibleName(_responsible) ??
                                  'Responsable',
                        Icons.person_outline,
                        _metadata == null
                            ? null
                            : () => _filter(
                                'Responsable',
                                [
                                  for (final r in _metadata!.responsibles)
                                    SearchablePickerOption(
                                      value: r.id,
                                      label: r.label,
                                    ),
                                ],
                                _responsible,
                                (v) => _responsible = v,
                              ),
                      ),
                      _filterButton(
                        _urgency ?? 'Vigencia',
                        Icons.event_outlined,
                        () => _filter(
                          'Vigencia',
                          _options(
                            DocumentalUrgency.values.map((u) => u.label),
                          ),
                          _urgency,
                          (v) => _urgency = v,
                        ),
                      ),
                      if (_isProcedure)
                        _filterButton(
                          _priority ?? 'Prioridad',
                          Icons.flag_outlined,
                          () => _filter(
                            'Prioridad',
                            _options(documentalPriorities),
                            _priority,
                            (v) => _priority = v,
                          ),
                        ),
                      if (filtered)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _search.clear();
                              _status = null;
                              _type = null;
                              _responsible = null;
                              _urgency = null;
                              _priority = null;
                            });
                            _filterChanged();
                          },
                          child: const Text('Limpiar'),
                        ),
                      ElevatedButton.icon(
                        style: contractPrimaryButtonStyle(context),
                        onPressed: _metadata == null || _detailOpen
                            ? null
                            : () => _open(),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Nuevo'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        TextButton(
                          onPressed: _loading ? null : _requestRefresh,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                if (_loading)
                  LinearProgressIndicator(
                    color: t.primary,
                    backgroundColor: t.primary.withValues(alpha: 0.1),
                  ),
                const SizedBox(height: 8),
                if (_metadata != null && _result.records.isEmpty && !_loading)
                  DocumentalEmptyState(
                    icon: _category.icon,
                    title: filtered
                        ? 'Sin coincidencias'
                        : (_isProcedure
                              ? 'Sin trámites registrados'
                              : 'Expediente por integrar'),
                    description: filtered
                        ? 'Ajusta los filtros para encontrar el expediente.'
                        : (_isProcedure
                              ? 'Registra el primer trámite con Nuevo y da seguimiento a su avance y vencimiento.'
                              : 'Registra el primer documento legal con Nuevo. La fecha de vencimiento es opcional.'),
                  ),
                if (_result.records.isNotEmpty && _metadata != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_selection.selectedIds.length} seleccionados',
                          style: TextStyle(color: t.primarySoft, fontSize: 12),
                        ),
                      ),
                      _filterButton(
                        switch (_sort) {
                          'name' => 'Nombre A–Z',
                          'expiration' => 'Vencimiento',
                          _ => 'Más recientes',
                        },
                        Icons.sort_rounded,
                        () async {
                          final selected =
                              await showSearchablePickerDialog<String>(
                                context,
                                title: 'Ordenar documentos',
                                initialValue: _sort,
                                options: const [
                                  SearchablePickerOption(
                                    value: 'recent',
                                    label: 'Más recientes',
                                  ),
                                  SearchablePickerOption(
                                    value: 'name',
                                    label: 'Nombre A–Z',
                                  ),
                                  SearchablePickerOption(
                                    value: 'expiration',
                                    label: 'Vencimiento',
                                  ),
                                ],
                              );
                          if (selected != null && mounted) {
                            setState(() => _sort = selected);
                            _filterChanged();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridKeyboardShell(
                    navigationController: _navigation,
                    focusNode: _gridFocus,
                    onNavigated: _navigated,
                    onConfirm: _openSelected,
                    onOpenActiveCell: _openSelected,
                    onEscape: _selection.clear,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact =
                            constraints.maxWidth < (_isProcedure ? 1100 : 850);
                        return Column(
                          children: [
                            if (!compact)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  8,
                                  12,
                                  12,
                                ),
                                child: Row(
                                  children: [
                                    for (final field in _columns)
                                      Expanded(
                                        flex: field.$2,
                                        child: Text(
                                          field.$1,
                                          style: TextStyle(
                                            color: t.primarySoft,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    SizedBox(width: _isProcedure ? 96 : 48),
                                  ],
                                ),
                              ),
                            for (var i = 0; i < _result.records.length; i++)
                              _recordRow(_result.records[i], i, compact),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${_page * 50 + 1}–${_page * 50 + _result.records.length} de ${_result.total}',
                      ),
                      IconButton(
                        tooltip: 'Página anterior',
                        onPressed: _page == 0 || _loading
                            ? null
                            : () {
                                setState(() => _page--);
                                _requestRefresh();
                              },
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      IconButton(
                        tooltip: 'Página siguiente',
                        onPressed: (_page + 1) * 50 >= _result.total || _loading
                            ? null
                            : () {
                                setState(() => _page++);
                                _requestRefresh();
                              },
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: DocumentalBadge(
                    _isProcedure
                        ? 'Admite trámites sin vencimiento'
                        : 'Admite documentos sin vencimiento',
                    icon: Icons.all_inclusive_rounded,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterButton(String label, IconData icon, VoidCallback? onPressed) =>
      OutlinedButton.icon(
        style: contractSecondaryButtonStyle(context),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(label, overflow: TextOverflow.ellipsis),
        ),
      );
  Widget _recordRow(DocumentalRecord record, int index, bool compact) {
    final t = AreaThemeScope.of(context);
    final selected = _selection.isSelected(record.id);
    final urgency = documentalUrgency(
      record.status,
      record.expiration,
      _metadata!.today,
    );
    final days = record.expiration == null
        ? null
        : documentalDaysRemaining(record.expiration!, _metadata!.today);
    final due = record.expiration == null
        ? 'Sin vencimiento'
        : MaterialLocalizations.of(
            context,
          ).formatCompactDate(record.expiration!);
    final responsible = _metadata!.responsibleName(record.responsibleId);
    Widget textCell(String value) => Text(
      value.isEmpty ? '—' : value,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          record.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          _isProcedure && !compact
              ? (record.reference.isEmpty
                    ? record.type
                    : '${record.reference} · ${record.type}')
              : (record.reference.isEmpty
                    ? record.status
                    : '${record.reference} · ${record.status}'),
          style: TextStyle(fontSize: 12, color: t.primarySoft),
        ),
      ],
    );
    final action = SizedBox(
      width: _isProcedure ? 96 : 48,
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: IconButton(
              tooltip: 'Abrir ${record.title}',
              onPressed: () => _open(record: record),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
            ),
          ),
          if (_isProcedure)
            SizedBox(
              width: 48,
              child: IconButton(
                tooltip: 'Actualizar seguimiento de ${record.title}',
                onPressed: () => _open(record: record, followUp: true),
                icon: const Icon(Icons.edit_note_rounded, size: 22),
              ),
            ),
        ],
      ),
    );
    final cells = _isProcedure
        ? <Widget>[
            title,
            textCell(record.authority),
            textCell(responsible),
            textCell(due),
            textCell(days?.toString() ?? '—'),
            textCell(record.priority),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.status,
                  style: TextStyle(color: t.primarySoft, fontSize: 12),
                ),
                const SizedBox(height: 6),
                DocumentalUrgencyBadge(urgency),
              ],
            ),
            DocumentalProgress(record.progress),
          ]
        : <Widget>[
            title,
            textCell(record.type),
            textCell(responsible),
            textCell(due),
            DocumentalUrgencyBadge(urgency),
          ];
    return Padding(
      key: _rowKeys.putIfAbsent(record.id, () => GlobalKey()),
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? t.primary.withValues(alpha: 0.16) : t.fieldSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? t.primary : t.border.withValues(alpha: 0.22),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _select(record, index),
          onDoubleTap: () => _open(record: record),
          onSecondaryTapDown: (details) =>
              _contextMenu(record, index, details.globalPosition),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: title),
                          action,
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_isProcedure) ...[
                        Text(
                          'Dependencia: ${record.authority.isEmpty ? '—' : record.authority}',
                          style: TextStyle(color: t.primarySoft, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        '${record.type} · $responsible',
                        style: TextStyle(color: t.primarySoft, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          DocumentalBadge(due),
                          if (_isProcedure && days != null)
                            DocumentalBadge('$days días restantes'),
                          if (_isProcedure)
                            DocumentalBadge('Prioridad ${record.priority}'),
                          DocumentalUrgencyBadge(urgency),
                        ],
                      ),
                      if (_isProcedure) ...[
                        const SizedBox(height: 12),
                        DocumentalProgress(record.progress),
                      ],
                    ],
                  )
                : Row(
                    children: [
                      for (var i = 0; i < cells.length; i++)
                        Expanded(
                          flex: _columns[i].$2,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: cells[i],
                          ),
                        ),
                      action,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
