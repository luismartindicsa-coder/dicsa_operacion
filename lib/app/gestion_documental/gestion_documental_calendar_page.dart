import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../shared/archetypes/auxiliary_surfaces/date_picker_surface.dart';
import '../shared/archetypes/auxiliary_surfaces/searchable_picker.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/ui_contract_core/refresh/lifecycle_refresh_scope.dart';
import 'gestion_documental_area_chrome.dart';
import 'gestion_documental_catalog.dart';
import 'gestion_documental_widgets.dart';
import 'gestion_documental_record_draft.dart';
import 'gestion_documental_records.dart';
import 'gestion_documental_store.dart';
import 'gestion_documental_overview.dart';
import 'gestion_documental_live_overview.dart';

class GestionDocumentalCalendarPage extends StatelessWidget {
  final Route<dynamic> dashboardRoute;
  const GestionDocumentalCalendarPage({
    super.key,
    required this.dashboardRoute,
  });
  @override
  Widget build(BuildContext context) => GestionDocumentalAreaShell(
    current: 'calendario',
    dashboardRoute: dashboardRoute,
    workspaceBuilder: (context, navigate) =>
        _CalendarWorkspace(onBack: () => navigate('dashboard')),
  );
}

class _CalendarWorkspace extends StatefulWidget {
  final VoidCallback onBack;
  const _CalendarWorkspace({required this.onBack});
  @override
  State<_CalendarWorkspace> createState() => _CalendarWorkspaceState();
}

class _CalendarWorkspaceState extends State<_CalendarWorkspace> {
  DocumentalLiveOverview<DocumentalCalendarData>? _live;
  DocumentalContext? _metadata;
  DateTime? _selected, _month;
  String? _category, _status, _responsible;
  DocumentalEventKind? _kind;
  int _page = 0;
  DateTime get _shownDay =>
      _selected ??
      _live?.data?.selected ??
      _metadata?.today ??
      DateUtils.dateOnly(DateTime.now());
  DateTime get _shownMonth =>
      _month ?? _live?.data?.month ?? DateTime(_shownDay.year, _shownDay.month);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_live != null) return;
    final repository = DocumentalRepositoryScope.of(context);
    _live = DocumentalLiveOverview(
      repository: repository,
      load: () => repository.loadCalendar(
        DocumentalCalendarQuery(
          month: _month,
          selected: _selected,
          category: _category,
          status: _status,
          responsibleId: _responsible,
          kind: _kind,
          page: _page,
        ),
      ),
      contextOf: (data) => data.context,
    )..addListener(_updated);
    _live!.refresh();
  }

  void _updated() {
    if (!mounted) return;
    final data = _live?.data;
    if (data != null) {
      _metadata = data.context;
      if (_page > 0 && _page * 50 >= data.total) {
        _page = data.total == 0 ? 0 : (data.total - 1) ~/ 50;
        _live!.refresh(reset: true);
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _live?.dispose();
    super.dispose();
  }

  void _changed() {
    _page = 0;
    _live!.refresh(reset: true);
  }

  void _select(DateTime day) {
    _selected = DateUtils.dateOnly(day);
    _month = DateTime(day.year, day.month);
    _changed();
  }

  Future<void> _pickFilter(
    String title,
    String all,
    List<SearchablePickerOption<String>> options,
    String? current,
    ValueChanged<String?> apply,
  ) async {
    final choices = [SearchablePickerOption(value: '', label: all), ...options]
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    final value = await showSearchablePickerDialog<String>(
      context,
      title: title,
      initialValue: current ?? '',
      options: choices,
    );
    if (!mounted || value == null) return;
    apply(value.isEmpty ? null : value);
    _changed();
  }

  Future<void> _pickDate() async {
    final value = await showContractDatePickerSurface(
      context,
      initialDate: _shownDay,
      firstDate: DateTime(1900),
      lastDate: DateTime(_metadata!.today.year + 100, 12, 31),
      title: 'Ir a una fecha',
    );
    if (mounted && value != null) _select(value);
  }

  void _changeMonth(int step) {
    final month = DateTime(_shownMonth.year, _shownMonth.month + step);
    _select(
      DateTime(
        month.year,
        month.month,
        _shownDay.day.clamp(
          1,
          DateUtils.getDaysInMonth(month.year, month.month),
        ),
      ),
    );
  }

  Widget _button(String label, IconData icon, VoidCallback action) =>
      OutlinedButton.icon(
        onPressed: _metadata == null ? null : action,
        style: contractSecondaryButtonStyle(context),
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
  @override
  Widget build(BuildContext context) {
    final t = AreaThemeScope.of(context);
    final dates = MaterialLocalizations.of(context);
    final data = _live?.data;
    final categoryLabel = _category == null
        ? 'Todas las categorías'
        : documentalCategories.firstWhere((c) => c.key == _category).title;
    return LifecycleRefreshScope(
      onResume: () async {
        await _live?.refresh();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onBack,
              style: TextButton.styleFrom(foregroundColor: t.primary),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Dashboard Gestión Documental'),
            ),
          ),
          const SizedBox(height: 8),
          DocumentalPageHeading(
            title: 'Calendario',
            description:
                'Vencimientos, renovaciones y obligaciones de todas las categorías.',
            action: DocumentalBadge(
              data == null ? '— fechas' : '${data.monthTotal} fechas este mes',
              key: const ValueKey('calendar-month-total'),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _button(
                categoryLabel,
                Icons.filter_alt_outlined,
                () => _pickFilter(
                  'Categoría documental',
                  'Todas las categorías',
                  [
                    for (final c in documentalCategories)
                      SearchablePickerOption(value: c.key, label: c.title),
                  ],
                  _category,
                  (v) => _category = v,
                ),
              ),
              _button(
                _kind?.label ?? 'Todas las fechas',
                Icons.event_note_outlined,
                () => _pickFilter(
                  'Tipo de fecha',
                  'Todas las fechas',
                  [
                    for (final k in DocumentalEventKind.values)
                      SearchablePickerOption(value: k.key, label: k.label),
                  ],
                  _kind?.key,
                  (v) => _kind = v == null
                      ? null
                      : DocumentalEventKind.values.firstWhere(
                          (k) => k.key == v,
                        ),
                ),
              ),
              _button(
                _responsible == null
                    ? 'Responsable'
                    : _metadata!.responsibleName(_responsible),
                Icons.person_outline,
                () => _pickFilter(
                  'Responsable interno',
                  'Todos los responsables',
                  [
                    for (final r in _metadata!.responsibles)
                      SearchablePickerOption(value: r.id, label: r.label),
                  ],
                  _responsible,
                  (v) => _responsible = v,
                ),
              ),
              _button(
                _status ?? 'Estatus',
                Icons.tune_rounded,
                () => _pickFilter(
                  'Estatus del proceso',
                  'Todos los estatus',
                  [
                    for (final s in documentalProcessStatuses)
                      SearchablePickerOption(value: s, label: s),
                  ],
                  _status,
                  (v) => _status = v,
                ),
              ),
              _button('Ir a fecha', Icons.event_rounded, _pickDate),
              OutlinedButton(
                onPressed: _metadata == null
                    ? null
                    : () {
                        _selected = null;
                        _month = null;
                        _changed();
                      },
                style: contractSecondaryButtonStyle(context),
                child: const Text('Hoy'),
              ),
              if (_category != null ||
                  _status != null ||
                  _responsible != null ||
                  _kind != null)
                TextButton(
                  onPressed: () {
                    _category = _status = _responsible = null;
                    _kind = null;
                    _changed();
                  },
                  child: const Text('Limpiar filtros'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          DocumentalOverviewFeedback(
            loading: _live?.loading ?? true,
            error: _live?.error ?? _live?.actionError,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final calendar = ContractGlassCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Mes anterior',
                          onPressed: _metadata == null
                              ? null
                              : () => _changeMonth(-1),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: Text(
                            dates.formatMonthYear(_shownMonth),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: t.onGlass,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Mes siguiente',
                          onPressed: _metadata == null
                              ? null
                              : () => _changeMonth(1),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DocumentalMonthGrid(
                      month: _shownMonth,
                      selected: _shownDay,
                      today: _metadata?.today,
                      counts: data?.days,
                      onSelected: _metadata == null ? null : _select,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Selecciona un día para consultar sus fechas.',
                        style: TextStyle(
                          color: t.onGlass.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
              final agenda = ContractGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Agenda del día',
                      style: TextStyle(
                        color: t.onGlass,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dates.formatFullDate(_shownDay),
                      style: TextStyle(
                        color: t.primarySoft,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DocumentalBadge(categoryLabel),
                    if (data != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        '${data.total} ${data.total == 1 ? 'fecha' : 'fechas'}',
                        key: const ValueKey('calendar-day-total'),
                        style: TextStyle(color: t.primarySoft),
                      ),
                      if (data.total == 0)
                        const DocumentalEmptyState(
                          title: 'Sin fechas para este día',
                          description:
                              'No hay fechas que coincidan con los filtros seleccionados.',
                          icon: Icons.event_available_outlined,
                        ),
                      for (final event in data.events)
                        DocumentalEventTile(
                          event: event,
                          metadata: data.context,
                          onOpen: () => _live!.open(context, event),
                        ),
                      if (data.total > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${_page * 50 + 1}–${_page * 50 + data.events.length} de ${data.total}',
                                  style: TextStyle(
                                    color: t.primarySoft,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Página anterior',
                                onPressed: _page == 0 || _live!.loading
                                    ? null
                                    : () {
                                        _page--;
                                        _live!.refresh(reset: true);
                                      },
                                icon: const Icon(Icons.chevron_left_rounded),
                              ),
                              IconButton(
                                tooltip: 'Página siguiente',
                                onPressed:
                                    (_page + 1) * 50 >= data.total ||
                                        _live!.loading
                                    ? null
                                    : () {
                                        _page++;
                                        _live!.refresh(reset: true);
                                      },
                                icon: const Icon(Icons.chevron_right_rounded),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              );
              if (constraints.maxWidth < 950) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [calendar, const SizedBox(height: 16), agenda],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: calendar),
                  const SizedBox(width: 16),
                  Expanded(child: agenda),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DocumentalMonthGrid extends StatefulWidget {
  final DateTime month, selected;
  final DateTime? today;
  final Map<String, int>? counts;
  final ValueChanged<DateTime>? onSelected;
  const _DocumentalMonthGrid({
    required this.month,
    required this.selected,
    required this.today,
    required this.counts,
    required this.onSelected,
  });
  @override
  State<_DocumentalMonthGrid> createState() => _DocumentalMonthGridState();
}

class _DocumentalMonthGridState extends State<_DocumentalMonthGrid> {
  final _nodes = <String, FocusNode>{};
  @override
  void dispose() {
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _move(int days) {
    final date = DateTime(
      widget.selected.year,
      widget.selected.month,
      widget.selected.day + days,
    );
    widget.onSelected?.call(date);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nodes[documentalDateJson(date)]?.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AreaThemeScope.of(context);
    final month = widget.month;
    final firstOffset = month.weekday - 1;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final cells = ((firstOffset + days) / 7).ceil() * 7;
    return Focus(
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent || widget.onSelected == null) {
          return KeyEventResult.ignored;
        }
        final step = switch (event.logicalKey) {
          LogicalKeyboardKey.arrowLeft => -1,
          LogicalKeyboardKey.arrowRight => 1,
          LogicalKeyboardKey.arrowUp => -7,
          LogicalKeyboardKey.arrowDown => 7,
          _ => 0,
        };
        if (step == 0) return KeyEventResult.ignored;
        _move(step);
        return KeyEventResult.handled;
      },
      child: Column(
        children: [
          Row(
            children: [
              for (final label in const [
                'Lun',
                'Mar',
                'Mié',
                'Jue',
                'Vie',
                'Sáb',
                'Dom',
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: t.primarySoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) => GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cells,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: constraints.maxWidth < 400 ? 42 : 68,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemBuilder: (context, index) {
                final day = index - firstOffset + 1;
                if (day < 1 || day > days) return const SizedBox.shrink();
                final date = DateTime(month.year, month.month, day);
                final dateKey = documentalDateJson(date)!;
                final count = widget.counts == null
                    ? null
                    : widget.counts![dateKey] ?? 0;
                final selected = DateUtils.isSameDay(date, widget.selected);
                final today = DateUtils.isSameDay(date, widget.today);
                return Semantics(
                  selected: selected,
                  label:
                      '${MaterialLocalizations.of(context).formatFullDate(date)} · ${count == null ? 'Fechas no disponibles' : '$count fechas'}',
                  child: OutlinedButton(
                    key: ValueKey('calendar-day-$dateKey'),
                    focusNode: _nodes.putIfAbsent(dateKey, FocusNode.new),
                    onPressed: widget.onSelected == null
                        ? null
                        : () {
                            _nodes[dateKey]!.requestFocus();
                            widget.onSelected!(date);
                          },
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: selected ? t.fieldSurface : t.onGlass,
                      backgroundColor: selected
                          ? t.primary
                          : t.fieldSurface.withValues(alpha: 0.6),
                      side: BorderSide(
                        color: today || selected
                            ? t.primary
                            : t.border.withValues(alpha: 0.16),
                        width: today ? 1.5 : 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: today || selected
                                ? FontWeight.w900
                                : FontWeight.w600,
                          ),
                        ),
                        if (count != null && count > 0)
                          Text(
                            count > 99 ? '99+' : '$count',
                            key: ValueKey('calendar-count-$dateKey'),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
