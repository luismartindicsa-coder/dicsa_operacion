import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import 'commercial_area_chrome.dart';
import 'commercial_dashboard_page.dart';
import 'commercial_development_dashboard_page.dart';
import 'commercial_directory_page.dart';
import 'commercial_store.dart';
import 'commercial_theme.dart';

enum _AgendaView { all, upcoming, completed }

class CommercialAgendaPage extends StatefulWidget {
  final bool instantOpen;

  const CommercialAgendaPage({super.key, this.instantOpen = false});

  @override
  State<CommercialAgendaPage> createState() => _CommercialAgendaPageState();
}

class _CommercialAgendaPageState extends State<CommercialAgendaPage> {
  bool _menuOpen = false;
  bool _loading = true;
  bool _saving = false;
  bool _canReturnToDirection = false;
  _AgendaView _view = _AgendaView.upcoming;
  List<CommercialAgendaEntryRecord> _entries = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_resolveNavigationAccess());
    unawaited(_loadAgenda());
  }

  Future<void> _resolveNavigationAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(() {
      _canReturnToDirection = AuthAccess.canAccessGeneralDashboard(profile);
    });
  }

  Future<void> _loadAgenda() async {
    setState(() => _loading = true);
    try {
      final entries = await CommercialStore.loadAgenda();
      if (!mounted) return;
      setState(() => _entries = entries);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEntryDialog([CommercialAgendaEntryRecord? entry]) async {
    final draft = await showDialog<_AgendaEntryDraft>(
      context: context,
      builder: (_) => _AgendaEntryDialog(entry: entry),
    );
    if (draft == null) return;
    await _runOperation(
      successMessage: entry == null
          ? 'Evento agregado a la agenda.'
          : 'Evento actualizado.',
      action: () => CommercialStore.saveAgendaEntry(
        entryId: entry?.id,
        title: draft.title,
        eventType: draft.eventType,
        startsAt: draft.startsAt,
        location: draft.location,
        notes: draft.notes,
        status: draft.status,
      ),
    );
  }

  Future<void> _changeStatus(
    CommercialAgendaEntryRecord entry,
    String status,
  ) async {
    await _runOperation(
      successMessage: status == 'realizado'
          ? 'Evento marcado como realizado.'
          : 'Evento actualizado.',
      action: () =>
          CommercialStore.updateAgendaStatus(entryId: entry.id, status: status),
    );
  }

  Future<void> _deleteEntry(CommercialAgendaEntryRecord entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar evento'),
        content: Text('¿Eliminar “${entry.title}” de la agenda?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runOperation(
      successMessage: 'Evento eliminado.',
      action: () => CommercialStore.deleteAgendaEntry(entry.id),
    );
  }

  Future<void> _runOperation({
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    setState(() => _saving = true);
    try {
      await action();
      await _loadAgenda();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar el evento. Intenta nuevamente.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async => signOutAndRouteToLogin(context);

  Future<void> _openDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const CommercialDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openDevelopmentDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const CommercialDevelopmentDashboardPage(instantOpen: true),
      ),
    );
  }

  Future<void> _openDirectory() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const CommercialDirectoryPage(instantOpen: true)),
    );
  }

  Future<void> _openDirectionDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final visibleEntries = _entries
        .where((entry) {
          return switch (_view) {
            _AgendaView.all => true,
            _AgendaView.upcoming =>
              entry.status == 'programado' && !entry.startsAt.isBefore(today),
            _AgendaView.completed => entry.status == 'realizado',
          };
        })
        .toList(growable: false);
    final todayCount = _entries.where((entry) {
      return DateUtils.isSameDay(entry.startsAt, today) &&
          entry.status == 'programado';
    }).length;
    final upcomingCount = _entries.where((entry) {
      return entry.status == 'programado' && !entry.startsAt.isBefore(today);
    }).length;

    return AreaThemeScope(
      tokens: commercialAreaTokens,
      child: Theme(
        data: buildCommercialAreaTheme(Theme.of(context)),
        child: Focus(
          autofocus: true,
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent ||
                event.logicalKey != LogicalKeyboardKey.escape) {
              return KeyEventResult.ignored;
            }
            if (_menuOpen) {
              setState(() => _menuOpen = false);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: AppShell(
            background: const CommercialAreaBackground(),
            wrapBodyInGlass: false,
            animateHeaderSlots: false,
            animateBody: !widget.instantOpen,
            headerBodySpacing: 8,
            padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
            leadingBuilder: (_, _) => CommercialAreaHeaderButton(
              label: _menuOpen ? 'Cerrar panel' : 'Navegación',
              icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
              onTapSync: () => setState(() => _menuOpen = !_menuOpen),
            ),
            centerBuilder: (_, _) => const _AgendaHeaderBrand(),
            trailingBuilder: (_, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CommercialAreaHeaderButton(
                  label: 'Recargar',
                  icon: Icons.refresh_rounded,
                  compact: true,
                  onTap: _loadAgenda,
                ),
                const SizedBox(width: 10),
                CommercialAreaHeaderButton(
                  label: 'Cerrar sesión',
                  icon: Icons.logout_rounded,
                  onTap: _logout,
                ),
              ],
            ),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(56, 0, 6, 0),
                      child: Column(
                        children: [
                          _AgendaTopBar(
                            view: _view,
                            todayCount: todayCount,
                            upcomingCount: upcomingCount,
                            totalCount: _entries.length,
                            saving: _saving,
                            onViewChanged: (value) =>
                                setState(() => _view = value),
                            onAdd: () => _openEntryDialog(),
                          ),
                          const SizedBox(height: 18),
                          Expanded(
                            child: _AgendaPanel(
                              child: _loading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : visibleEntries.isEmpty
                                  ? const _AgendaEmptyState()
                                  : ListView.separated(
                                      padding: const EdgeInsets.all(18),
                                      itemCount: visibleEntries.length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(height: 10),
                                      itemBuilder: (_, index) =>
                                          _AgendaEntryCard(
                                            entry: visibleEntries[index],
                                            saving: _saving,
                                            onEdit: () => _openEntryDialog(
                                              visibleEntries[index],
                                            ),
                                            onComplete: () => _changeStatus(
                                              visibleEntries[index],
                                              'realizado',
                                            ),
                                            onDelete: () => _deleteEntry(
                                              visibleEntries[index],
                                            ),
                                          ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !_menuOpen,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: _menuOpen ? 1 : 0,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _menuOpen = false),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: _menuOpen ? 0 : -332,
                  top: 0,
                  bottom: 0,
                  width: 320,
                  child: IgnorePointer(
                    ignoring: !_menuOpen,
                    child: CommercialAreaSidePanel(
                      label: 'Desarrollo Comercial',
                      canReturnToDirection: _canReturnToDirection,
                      areaItems: [
                        CommercialAreaNavEntry(
                          icon: Icons.radar_rounded,
                          title: 'Radar Comercial',
                          subtitle: 'Alertas, materiales y contexto',
                          onTap: _openDashboard,
                        ),
                        CommercialAreaNavEntry(
                          icon: Icons.badge_outlined,
                          title: 'Directorio Comercial',
                          subtitle: 'Cuentas, contactos y seguimiento',
                          onTap: _openDirectory,
                        ),
                        const CommercialAreaNavEntry(
                          icon: Icons.calendar_month_rounded,
                          title: 'Agenda Comercial',
                          subtitle: 'Citas, reuniones y eventos',
                          accented: true,
                        ),
                      ],
                      accessItems: [
                        if (_canReturnToDirection)
                          CommercialAreaNavEntry(
                            icon: Icons.assessment_outlined,
                            title: 'Dashboard Dirección',
                            subtitle: 'Vista ejecutiva multiarea',
                            onTap: _openDirectionDashboard,
                          ),
                        CommercialAreaNavEntry(
                          icon: Icons.dashboard_outlined,
                          title: 'Dashboard Comercial',
                          subtitle: 'Resumen de desarrollo comercial',
                          onTap: _openDevelopmentDashboard,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AgendaHeaderBrand extends StatelessWidget {
  const _AgendaHeaderBrand();

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
          ),
          child: const Center(child: DicsaLogoD(size: 38, progress: 1)),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Agenda Comercial',
              style: TextStyle(
                color: Color(0xFFF0E9D1),
                fontSize: 28,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Citas, reuniones, foros y convenciones',
              style: TextStyle(
                color: tokens.badgeText,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AgendaTopBar extends StatelessWidget {
  final _AgendaView view;
  final int todayCount;
  final int upcomingCount;
  final int totalCount;
  final bool saving;
  final ValueChanged<_AgendaView> onViewChanged;
  final VoidCallback onAdd;

  const _AgendaTopBar({
    required this.view,
    required this.todayCount,
    required this.upcomingCount,
    required this.totalCount,
    required this.saving,
    required this.onViewChanged,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xB814231C),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final controls = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AgendaFilterChip(
                label: 'Próximos',
                selected: view == _AgendaView.upcoming,
                onTap: () => onViewChanged(_AgendaView.upcoming),
              ),
              _AgendaFilterChip(
                label: 'Todos',
                selected: view == _AgendaView.all,
                onTap: () => onViewChanged(_AgendaView.all),
              ),
              _AgendaFilterChip(
                label: 'Realizados',
                selected: view == _AgendaView.completed,
                onTap: () => onViewChanged(_AgendaView.completed),
              ),
            ],
          );
          final summary = Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _AgendaCount(
                label: 'Hoy',
                value: '$todayCount',
                tone: tokens.primaryStrong,
              ),
              _AgendaCount(
                label: 'Próximos',
                value: '$upcomingCount',
                tone: const Color(0xFF56CCF2),
              ),
              _AgendaCount(
                label: 'Registrados',
                value: '$totalCount',
                tone: const Color(0xFFF2C94C),
              ),
            ],
          );
          final add = FilledButton.icon(
            onPressed: saving ? null : onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar evento'),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                controls,
                const SizedBox(height: 16),
                summary,
                const SizedBox(height: 16),
                add,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: controls),
              summary,
              const SizedBox(width: 18),
              add,
            ],
          );
        },
      ),
    );
  }
}

class _AgendaFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AgendaFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: tokens.primaryStrong.withValues(alpha: 0.30),
      labelStyle: TextStyle(color: tokens.onGlass, fontWeight: FontWeight.w800),
      side: BorderSide(color: tokens.border),
    );
  }
}

class _AgendaCount extends StatelessWidget {
  final String label;
  final String value;
  final Color tone;

  const _AgendaCount({
    required this.label,
    required this.value,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: tone,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: AreaThemeScope.of(context).badgeText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AgendaPanel extends StatelessWidget {
  final Widget child;
  const _AgendaPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xB814231C),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }
}

class _AgendaEmptyState extends StatelessWidget {
  const _AgendaEmptyState();

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 46,
            color: tokens.primaryStrong,
          ),
          const SizedBox(height: 14),
          Text(
            'Tu agenda está libre',
            style: TextStyle(
              color: tokens.onGlass,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Agrega una cita, reunión, foro o convención.',
            style: TextStyle(color: tokens.badgeText),
          ),
        ],
      ),
    );
  }
}

class _AgendaEntryCard extends StatelessWidget {
  final CommercialAgendaEntryRecord entry;
  final bool saving;
  final VoidCallback onEdit;
  final VoidCallback onComplete;
  final VoidCallback onDelete;

  const _AgendaEntryCard({
    required this.entry,
    required this.saving,
    required this.onEdit,
    required this.onComplete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final tone = _agendaTypeTone(entry.eventType);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  _shortMonth(entry.startsAt),
                  style: TextStyle(
                    color: tone,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${entry.startsAt.day}',
                  style: TextStyle(
                    color: tokens.onGlass,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      entry.title,
                      style: TextStyle(
                        color: tokens.onGlass,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    _AgendaBadge(
                      label: _agendaTypeLabel(entry.eventType),
                      tone: tone,
                    ),
                    _AgendaBadge(
                      label: _agendaStatusLabel(entry.status),
                      tone: _agendaStatusTone(entry.status),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '${_timeLabel(entry.startsAt)}${entry.location.isEmpty ? '' : ' · ${entry.location}'}',
                  style: TextStyle(
                    color: tokens.badgeText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (entry.notes.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    entry.notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.badgeText.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            enabled: !saving,
            onSelected: (action) {
              switch (action) {
                case 'edit':
                  onEdit();
                case 'complete':
                  onComplete();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Editar')),
              if (entry.status == 'programado')
                const PopupMenuItem(
                  value: 'complete',
                  child: Text('Marcar realizado'),
                ),
              const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
            ],
            icon: Icon(Icons.more_horiz_rounded, color: tokens.onGlass),
          ),
        ],
      ),
    );
  }
}

class _AgendaBadge extends StatelessWidget {
  final String label;
  final Color tone;
  const _AgendaBadge({required this.label, required this.tone});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: tone.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: tone,
        fontSize: 10.5,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _AgendaEntryDraft {
  final String title;
  final String eventType;
  final DateTime startsAt;
  final String location;
  final String notes;
  final String status;

  const _AgendaEntryDraft({
    required this.title,
    required this.eventType,
    required this.startsAt,
    required this.location,
    required this.notes,
    required this.status,
  });
}

class _AgendaEntryDialog extends StatefulWidget {
  final CommercialAgendaEntryRecord? entry;
  const _AgendaEntryDialog({this.entry});

  @override
  State<_AgendaEntryDialog> createState() => _AgendaEntryDialogState();
}

class _AgendaEntryDialogState extends State<_AgendaEntryDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _notesController;
  late DateTime _startsAt;
  late String _eventType;
  late String _status;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _titleController = TextEditingController(text: entry?.title ?? '');
    _locationController = TextEditingController(text: entry?.location ?? '');
    _notesController = TextEditingController(text: entry?.notes ?? '');
    _startsAt = entry?.startsAt ?? DateTime.now().add(const Duration(hours: 1));
    _eventType = entry?.eventType ?? 'cita';
    _status = entry?.status ?? 'programado';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (value == null || !mounted) return;
    setState(
      () => _startsAt = DateTime(
        value.year,
        value.month,
        value.day,
        _startsAt.hour,
        _startsAt.minute,
      ),
    );
  }

  Future<void> _pickTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (value == null || !mounted) return;
    setState(
      () => _startsAt = DateTime(
        _startsAt.year,
        _startsAt.month,
        _startsAt.day,
        value.hour,
        value.minute,
      ),
    );
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(
      _AgendaEntryDraft(
        title: title,
        eventType: _eventType,
        startsAt: _startsAt,
        location: _locationController.text.trim(),
        notes: _notesController.text.trim(),
        status: _status,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CommercialAreaDialogShell(
      title: widget.entry == null ? 'Nuevo evento' : 'Editar evento',
      subtitle: 'Registra una cita, reunión, foro o convención comercial.',
      onSave: _save,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Título del evento *',
              hintText: 'Ej. Reunión con cliente',
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _eventType,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: kCommercialAgendaTypeOptions
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(_agendaTypeLabel(value)),
                  ),
                )
                .toList(),
            onChanged: (value) =>
                setState(() => _eventType = value ?? _eventType),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(_dateLabel(_startsAt)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text(_timeLabel(_startsAt)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _locationController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Lugar o enlace',
              hintText: 'Opcional',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _notesController,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notas',
              hintText: 'Opcional',
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Estado'),
            items: kCommercialAgendaStatusOptions
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(_agendaStatusLabel(value)),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _status = value ?? _status),
          ),
        ],
      ),
    );
  }
}

Color _agendaTypeTone(String type) => switch (type) {
  'cita' => const Color(0xFF56CCF2),
  'reunion' => const Color(0xFF41D978),
  'foro' => const Color(0xFFF2C94C),
  'convencion' => const Color(0xFFB27CFF),
  _ => const Color(0xFFF2994A),
};

Color _agendaStatusTone(String status) => switch (status) {
  'realizado' => const Color(0xFF41D978),
  'cancelado' => const Color(0xFFFF5B4D),
  _ => const Color(0xFF56CCF2),
};

String _agendaTypeLabel(String type) => switch (type) {
  'cita' => 'Cita',
  'reunion' => 'Reunión',
  'foro' => 'Foro',
  'convencion' => 'Convención',
  _ => 'Otro',
};

String _agendaStatusLabel(String status) => switch (status) {
  'realizado' => 'Realizado',
  'cancelado' => 'Cancelado',
  _ => 'Programado',
};

String _shortMonth(DateTime value) {
  const months = [
    'ENE',
    'FEB',
    'MAR',
    'ABR',
    'MAY',
    'JUN',
    'JUL',
    'AGO',
    'SEP',
    'OCT',
    'NOV',
    'DIC',
  ];
  return months[value.month - 1];
}

String _dateLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')} ${_shortMonth(value)} ${value.year}';

String _timeLabel(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
