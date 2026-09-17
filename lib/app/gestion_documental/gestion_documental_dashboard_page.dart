import 'package:flutter/material.dart';

import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import 'gestion_documental_area_chrome.dart';
import 'gestion_documental_catalog.dart';
import 'gestion_documental_widgets.dart';
import 'gestion_documental_store.dart';
import 'gestion_documental_overview.dart';
import 'gestion_documental_live_overview.dart';
import '../shared/ui_contract_core/refresh/lifecycle_refresh_scope.dart';

/// Dashboard archetype, based on EmptyAreaDashboard; pink area palette.
class GestionDocumentalDashboardPage extends StatelessWidget {
  final bool instantOpen;
  const GestionDocumentalDashboardPage({super.key, this.instantOpen = false});

  @override
  Widget build(BuildContext context) => GestionDocumentalAreaShell(
    current: 'dashboard',
    instantOpen: instantOpen,
    workspaceBuilder: (context, navigate) =>
        _DocumentalDashboardWorkspace(onNavigate: navigate),
  );
}

class _DocumentalDashboardWorkspace extends StatefulWidget {
  final void Function(String) onNavigate;
  const _DocumentalDashboardWorkspace({required this.onNavigate});
  @override
  State<_DocumentalDashboardWorkspace> createState() =>
      _DocumentalDashboardWorkspaceState();
}

class _DocumentalDashboardWorkspaceState
    extends State<_DocumentalDashboardWorkspace> {
  DocumentalLiveOverview<DocumentalDashboardData>? _live;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_live != null) return;
    final repository = DocumentalRepositoryScope.of(context);
    _live = DocumentalLiveOverview(
      repository: repository,
      load: repository.loadDashboard,
      contextOf: (data) => data.context,
    )..addListener(_updated);
    _live!.refresh();
  }

  void _updated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _live?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AreaThemeScope.of(context);
    final data = _live?.data;
    return LifecycleRefreshScope(
      onResume: () async {
        await _live?.refresh();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DocumentalPageHeading(
            title: 'Dashboard Gestión Documental',
            description:
                'Documentos, expedientes y obligaciones de DICSA en un solo lugar.',
            action: OutlinedButton.icon(
              onPressed: () => widget.onNavigate('calendario'),
              style: contractSecondaryButtonStyle(context),
              icon: const Icon(Icons.calendar_month_rounded, size: 20),
              label: const Text('Calendario'),
            ),
          ),
          const SizedBox(height: 18),
          DocumentalOverviewFeedback(
            loading: _live?.loading ?? true,
            error: _live?.error ?? _live?.actionError,
          ),
          _DocumentalMetrics(values: data?.metrics),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Expedientes por categoría',
                style: TextStyle(
                  color: t.onGlass,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Consulta registros, vencimientos y pendientes de cada categoría.',
            style: TextStyle(
              color: t.onGlass.withValues(alpha: 0.65),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1050
                  ? 3
                  : constraints.maxWidth >= 650
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final category in documentalCategories)
                    SizedBox(
                      width: width,
                      child: _DocumentalCategoryCard(
                        category: category,
                        counts: data?.counts(category.key),
                        onTap: () => widget.onNavigate(category.key),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          ContractGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DocumentalPageHeading(
                  title: 'Próximas fechas',
                  description:
                      'Vencimientos, renovaciones, inicios y actividades por atender.',
                  action: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: t.primary),
                    onPressed: () => widget.onNavigate('calendario'),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('Ver calendario'),
                  ),
                ),
                if (data != null) ...[
                  Text(
                    '${data.upcomingTotal} fechas en los próximos 30 días',
                    style: TextStyle(color: t.primarySoft, fontSize: 12),
                  ),
                  if (data.upcoming.isEmpty)
                    const DocumentalEmptyState(
                      title: 'Sin próximas fechas',
                      description:
                          'No hay vencimientos, renovaciones, inicios o actividades pendientes en este periodo.',
                      icon: Icons.event_available_outlined,
                    )
                  else ...[
                    for (final event in data.upcoming)
                      DocumentalEventTile(
                        event: event,
                        metadata: data.context,
                        onOpen: () => _live!.open(context, event),
                      ),
                    if (data.upcomingTotal > data.upcoming.length)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Se muestran las primeras ${data.upcoming.length} fechas. Consulta el resto en el calendario.',
                          style: TextStyle(color: t.primarySoft, fontSize: 12),
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentalMetrics extends StatelessWidget {
  final Map<String, int>? values;
  const _DocumentalMetrics({this.values});

  @override
  Widget build(BuildContext context) {
    final t = AreaThemeScope.of(context);
    const metrics = [
      (
        key: 'active',
        hint: 'Expedientes pendientes o en proceso.',
        label: 'Documentos activos',
        icon: Icons.description_outlined,
      ),
      (
        key: 'upcoming',
        hint:
            'Activos que vencen entre hoy y los próximos 15 días; incluye los críticos.',
        label: 'Próximos a vencer',
        icon: Icons.event_available_outlined,
      ),
      (
        key: 'critical',
        hint: 'Activos que vencen entre hoy y los próximos 5 días.',
        label: 'Documentos críticos',
        icon: Icons.priority_high_rounded,
      ),
      (
        key: 'expired',
        hint: 'Activos con vencimiento anterior a hoy.',
        label: 'Documentos vencidos',
        icon: Icons.event_busy_outlined,
      ),
      (
        key: 'pending_procedures',
        hint: 'Permisos y Trámites con estatus Pendiente.',
        label: 'Trámites pendientes',
        icon: Icons.pending_actions_rounded,
      ),
      (
        key: 'in_progress_procedures',
        hint: 'Permisos y Trámites con estatus En proceso.',
        label: 'Trámites en proceso',
        icon: Icons.timelapse_rounded,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 6
            : constraints.maxWidth >= 650
            ? 3
            : constraints.maxWidth >= 280
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: Tooltip(
                  message: metric.hint,
                  child: ContractGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(metric.icon, color: t.primary, size: 22),
                        const SizedBox(height: 10),
                        Text(
                          values?[metric.key]?.toString() ?? '—',
                          key: ValueKey('metric-${metric.key}'),
                          semanticsLabel:
                              '${metric.label}: ${values?[metric.key]?.toString() ?? 'Sin datos disponibles'}',
                          style: TextStyle(
                            color: t.onGlass,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          metric.label,
                          style: TextStyle(
                            color: t.onGlass.withValues(alpha: 0.75),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DocumentalCategoryCard extends StatelessWidget {
  final DocumentalCategory category;
  final VoidCallback onTap;
  final DocumentalCategoryCounts? counts;
  const _DocumentalCategoryCard({
    required this.category,
    required this.onTap,
    this.counts,
  });

  @override
  Widget build(BuildContext context) {
    final t = AreaThemeScope.of(context);
    return DocumentalActionCard(
      label: 'Abrir ${category.title}',
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DocumentalIcon(category.icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category.title,
                  style: TextStyle(
                    color: t.onGlass,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if ((counts?.pending ?? 0) > 0)
                Tooltip(
                  message:
                      '${counts!.pending} expedientes pendientes o en proceso',
                  child: Icon(
                    Icons.pending_actions_rounded,
                    color: t.primary,
                    size: 20,
                  ),
                ),
              Icon(Icons.chevron_right_rounded, color: t.primary, size: 23),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            category.description,
            style: TextStyle(
              color: t.onGlass.withValues(alpha: 0.68),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: t.border.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final entry in [
                ('Registros', counts?.total),
                ('Por vencer', counts?.upcoming),
                ('Vencidos', counts?.expired),
              ])
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.$2?.toString() ?? '—',
                        key: ValueKey('category-${category.key}-${entry.$1}'),
                        style: TextStyle(
                          color: t.primarySoft,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.$1,
                        style: TextStyle(
                          color: t.onGlass.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
