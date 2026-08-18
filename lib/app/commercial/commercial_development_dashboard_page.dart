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
import 'commercial_agenda_page.dart';
import 'commercial_area_chrome.dart';
import 'commercial_dashboard_page.dart';
import 'commercial_directory_page.dart';
import 'commercial_store.dart';
import 'commercial_theme.dart';

class CommercialDevelopmentDashboardPage extends StatefulWidget {
  final bool instantOpen;

  const CommercialDevelopmentDashboardPage({
    super.key,
    this.instantOpen = false,
  });

  @override
  State<CommercialDevelopmentDashboardPage> createState() =>
      _CommercialDevelopmentDashboardPageState();
}

class _CommercialDevelopmentDashboardPageState
    extends State<CommercialDevelopmentDashboardPage> {
  bool _menuOpen = false;
  bool _loading = true;
  bool _canReturnToDirection = false;
  CommercialDashboardBundle? _radar;
  CommercialDirectoryBundle? _directory;
  List<CommercialAgendaEntryRecord> _agenda = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_resolveNavigationAccess());
    unawaited(_loadDashboard());
  }

  Future<void> _resolveNavigationAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(
      () =>
          _canReturnToDirection = AuthAccess.canAccessGeneralDashboard(profile),
    );
  }

  Future<void> _loadDashboard() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        CommercialStore.loadDashboard(),
        CommercialStore.loadDirectory(),
        CommercialStore.loadAgenda(),
      ]);
      if (!mounted) return;
      setState(() {
        _radar = results[0] as CommercialDashboardBundle;
        _directory = results[1] as CommercialDirectoryBundle;
        _agenda = results[2] as List<CommercialAgendaEntryRecord>;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async => signOutAndRouteToLogin(context);

  Future<void> _openRadar() async => Navigator.of(context).pushReplacement(
    appPageRoute(page: const CommercialDashboardPage(instantOpen: true)),
  );

  Future<void> _openDirectory() async => Navigator.of(context).pushReplacement(
    appPageRoute(page: const CommercialDirectoryPage(instantOpen: true)),
  );

  Future<void> _openAgenda() async => Navigator.of(context).pushReplacement(
    appPageRoute(page: const CommercialAgendaPage(instantOpen: true)),
  );

  Future<void> _openDirectionDashboard() async =>
      Navigator.of(context).pushReplacement(
        appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
      );

  @override
  Widget build(BuildContext context) {
    final accounts =
        _directory?.accounts ?? const <CommercialDirectoryAccountRecord>[];
    final alerts = _radar?.alerts ?? const <CommercialAlertRecord>[];
    final today = DateUtils.dateOnly(DateTime.now());
    final directProspects = accounts.where(_isDirectProspect).length;
    final accountsWithFollowUp = accounts
        .where((row) => row.followUpCount > 0)
        .length;
    final criticalAlerts = alerts
        .where((alert) => alert.severity == 'critica')
        .length;
    final plannedAgenda =
        _agenda
            .where(
              (entry) =>
                  entry.status == 'programado' &&
                  !entry.startsAt.isBefore(today),
            )
            .toList(growable: false)
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final nextEvent = plannedAgenda.isEmpty ? null : plannedAgenda.first;

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
            centerBuilder: (_, _) => const _CommercialDevelopmentHeader(),
            trailingBuilder: (_, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CommercialAreaHeaderButton(
                  label: 'Recargar',
                  icon: Icons.refresh_rounded,
                  compact: true,
                  onTap: _loadDashboard,
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
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : ListView(
                              children: [
                                _DevelopmentPriorityCard(
                                  criticalAlerts: criticalAlerts,
                                  nextEvent: nextEvent,
                                  directProspects: directProspects,
                                  onOpenRadar: _openRadar,
                                  onOpenAgenda: _openAgenda,
                                ),
                                const SizedBox(height: 14),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final stacked = constraints.maxWidth < 920;
                                    final cards = [
                                      _DevelopmentSummaryCard(
                                        icon: Icons.badge_outlined,
                                        title: 'Directorio',
                                        metric: '$directProspects',
                                        metricLabel: 'prospectos creados aquí',
                                        details:
                                            '$accountsWithFollowUp cuentas con seguimiento',
                                        tone: const Color(0xFF56CCF2),
                                        actionLabel: 'Abrir directorio',
                                        onTap: _openDirectory,
                                      ),
                                      _DevelopmentSummaryCard(
                                        icon: Icons.radar_rounded,
                                        title: 'Radar',
                                        metric: '${alerts.length}',
                                        metricLabel: 'alertas activas',
                                        details:
                                            '${_radar?.kpis.materialsActive30d ?? 0} materiales activos en 30 días',
                                        tone: const Color(0xFFF2C94C),
                                        actionLabel: 'Revisar radar',
                                        onTap: _openRadar,
                                      ),
                                      _DevelopmentSummaryCard(
                                        icon: Icons.calendar_month_rounded,
                                        title: 'Agenda',
                                        metric: '${plannedAgenda.length}',
                                        metricLabel: 'eventos próximos',
                                        details: nextEvent == null
                                            ? 'Sin evento programado'
                                            : '${_agendaTypeLabel(nextEvent.eventType)} · ${_agendaDateTimeLabel(nextEvent.startsAt)}',
                                        tone: const Color(0xFF41D978),
                                        actionLabel: 'Abrir agenda',
                                        onTap: _openAgenda,
                                      ),
                                    ];
                                    if (stacked) {
                                      return Column(
                                        children: [
                                          for (
                                            var index = 0;
                                            index < cards.length;
                                            index++
                                          ) ...[
                                            cards[index],
                                            if (index < cards.length - 1)
                                              const SizedBox(height: 14),
                                          ],
                                        ],
                                      );
                                    }
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        for (
                                          var index = 0;
                                          index < cards.length;
                                          index++
                                        ) ...[
                                          Expanded(child: cards[index]),
                                          if (index < cards.length - 1)
                                            const SizedBox(width: 14),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 14),
                                _DevelopmentQuickList(
                                  title: 'Próximos eventos',
                                  emptyLabel:
                                      'No hay eventos próximos en la agenda.',
                                  entries: plannedAgenda
                                      .take(4)
                                      .toList(growable: false),
                                  onOpenAgenda: _openAgenda,
                                ),
                                const SizedBox(height: 24),
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
                          subtitle: 'Precio, alertas y contexto',
                          onTap: _openRadar,
                        ),
                        CommercialAreaNavEntry(
                          icon: Icons.badge_outlined,
                          title: 'Directorio Comercial',
                          subtitle: 'Cuentas, contactos y seguimiento',
                          onTap: _openDirectory,
                        ),
                        CommercialAreaNavEntry(
                          icon: Icons.calendar_month_rounded,
                          title: 'Agenda Comercial',
                          subtitle: 'Citas, reuniones y eventos',
                          onTap: _openAgenda,
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
                        const CommercialAreaNavEntry(
                          icon: Icons.dashboard_outlined,
                          title: 'Dashboard Comercial',
                          subtitle: 'Resumen de desarrollo comercial',
                          accented: true,
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

bool _isDirectProspect(CommercialDirectoryAccountRecord account) {
  return (account.sourceArea.trim().toLowerCase() == 'manual' ||
          account.sourceRecordId.trim().isEmpty) &&
      account.status != 'cerrado';
}

class _CommercialDevelopmentHeader extends StatelessWidget {
  const _CommercialDevelopmentHeader();

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.44)),
          ),
          child: const Center(child: DicsaLogoD(size: 40, progress: 1)),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Desarrollo Comercial',
              style: TextStyle(
                color: Color(0xFFF0E9D1),
                fontSize: 29,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Prospectos, señales de mercado y agenda',
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

class _DevelopmentPriorityCard extends StatelessWidget {
  final int criticalAlerts;
  final CommercialAgendaEntryRecord? nextEvent;
  final int directProspects;
  final Future<void> Function() onOpenRadar;
  final Future<void> Function() onOpenAgenda;

  const _DevelopmentPriorityCard({
    required this.criticalAlerts,
    required this.nextEvent,
    required this.directProspects,
    required this.onOpenRadar,
    required this.onOpenAgenda,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final hasCritical = criticalAlerts > 0;
    final primaryLabel = hasCritical
        ? '$criticalAlerts alertas críticas requieren revisión'
        : 'No hay alertas críticas pendientes';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xB814231C),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (hasCritical ? const Color(0xFFFF5B4D) : tokens.primaryStrong)
              .withValues(alpha: 0.36),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 840;
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Prioridad de hoy',
                style: TextStyle(
                  color: tokens.badgeText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                primaryLabel,
                style: TextStyle(
                  color: tokens.onGlass,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                nextEvent == null
                    ? '$directProspects prospectos directos disponibles para trabajar.'
                    : 'Próximo evento: ${nextEvent!.title} · ${_agendaDateTimeLabel(nextEvent!.startsAt)}',
                style: TextStyle(
                  color: tokens.badgeText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _DevelopmentAction(
                label: 'Ver radar',
                icon: Icons.radar_rounded,
                onTap: onOpenRadar,
              ),
              _DevelopmentAction(
                label: 'Ver agenda',
                icon: Icons.calendar_month_rounded,
                onTap: onOpenAgenda,
              ),
            ],
          );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [content, const SizedBox(height: 16), actions],
            );
          }
          return Row(
            children: [
              Expanded(child: content),
              const SizedBox(width: 20),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _DevelopmentSummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String metric;
  final String metricLabel;
  final String details;
  final Color tone;
  final String actionLabel;
  final Future<void> Function() onTap;

  const _DevelopmentSummaryCard({
    required this.icon,
    required this.title,
    required this.metric,
    required this.metricLabel,
    required this.details,
    required this.tone,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xB814231C),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: tone, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: tokens.onGlass,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            metric,
            style: TextStyle(
              color: tone,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            metricLabel,
            style: TextStyle(
              color: tokens.badgeText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            details,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tokens.badgeText, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          _DevelopmentAction(
            label: actionLabel,
            icon: Icons.arrow_forward_rounded,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _DevelopmentQuickList extends StatelessWidget {
  final String title;
  final String emptyLabel;
  final List<CommercialAgendaEntryRecord> entries;
  final Future<void> Function() onOpenAgenda;

  const _DevelopmentQuickList({
    required this.title,
    required this.emptyLabel,
    required this.entries,
    required this.onOpenAgenda,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: tokens.onGlass,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _DevelopmentAction(
                label: 'Agenda',
                icon: Icons.arrow_forward_rounded,
                onTap: onOpenAgenda,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Text(emptyLabel, style: TextStyle(color: tokens.badgeText))
          else
            for (var index = 0; index < entries.length; index++) ...[
              _QuickAgendaRow(entry: entries[index]),
              if (index < entries.length - 1)
                Divider(
                  color: Colors.white.withValues(alpha: 0.08),
                  height: 20,
                ),
            ],
        ],
      ),
    );
  }
}

class _QuickAgendaRow extends StatelessWidget {
  final CommercialAgendaEntryRecord entry;
  const _QuickAgendaRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF41D978).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.event_outlined, color: Color(0xFF41D978)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.title,
                style: TextStyle(
                  color: tokens.onGlass,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_agendaTypeLabel(entry.eventType)} · ${_agendaDateTimeLabel(entry.startsAt)}${entry.location.isEmpty ? '' : ' · ${entry.location}'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: tokens.badgeText, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DevelopmentAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Future<void> Function() onTap;
  const _DevelopmentAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => unawaited(onTap()),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: tokens.primaryStrong.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: tokens.primaryStrong.withValues(alpha: 0.34),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: tokens.primaryStrong, size: 17),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: tokens.onGlass,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _agendaTypeLabel(String type) => switch (type) {
  'cita' => 'Cita',
  'reunion' => 'Reunión',
  'foro' => 'Foro',
  'convencion' => 'Convención',
  _ => 'Otro',
};

String _agendaDateTimeLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
