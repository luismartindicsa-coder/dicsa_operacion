import 'package:flutter/material.dart';

import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import 'gestion_documental_area_chrome.dart';
import 'gestion_documental_catalog.dart';
import 'gestion_documental_widgets.dart';

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

class _DocumentalDashboardWorkspace extends StatelessWidget {
  final void Function(String) onNavigate;
  const _DocumentalDashboardWorkspace({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final t = AreaThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DocumentalPageHeading(
          title: 'Dashboard Gestión Documental',
          description:
              'Documentos, expedientes y obligaciones de DICSA en un solo lugar.',
          action: OutlinedButton.icon(
            onPressed: () => onNavigate('calendario'),
            style: contractSecondaryButtonStyle(context),
            icon: const Icon(Icons.calendar_month_rounded, size: 20),
            label: const Text('Calendario'),
          ),
        ),
        const SizedBox(height: 18),
        const _DocumentalMetrics(),
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
            const DocumentalBadge('Vista inicial'),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Explora cada categoría. Los registros y sus indicadores se habilitarán progresivamente.',
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
            final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final category in documentalCategories)
                  SizedBox(
                    width: width,
                    child: _DocumentalCategoryCard(
                      category: category,
                      onTap: () => onNavigate(category.key),
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
                title: 'Próximos vencimientos',
                description: 'Vigencias, renovaciones y fechas por atender.',
                action: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: t.primary),
                  onPressed: () => onNavigate('calendario'),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Ver calendario'),
                ),
              ),
              const DocumentalEmptyState(
                title: 'Vencimientos por incorporar',
                description:
                    'Aquí podrás consultar las próximas fechas de los expedientes y abrir su detalle.',
                icon: Icons.event_note_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DocumentalMetrics extends StatelessWidget {
  const _DocumentalMetrics();

  @override
  Widget build(BuildContext context) {
    final t = AreaThemeScope.of(context);
    const metrics = [
      (label: 'Documentos activos', icon: Icons.description_outlined),
      (label: 'Próximos a vencer', icon: Icons.event_available_outlined),
      (label: 'Documentos críticos', icon: Icons.priority_high_rounded),
      (label: 'Documentos vencidos', icon: Icons.event_busy_outlined),
      (label: 'Trámites pendientes', icon: Icons.pending_actions_rounded),
      (label: 'Trámites en proceso', icon: Icons.timelapse_rounded),
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
                child: ContractGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(metric.icon, color: t.primary, size: 22),
                      const SizedBox(height: 10),
                      Text(
                        '—',
                        semanticsLabel: 'Sin datos disponibles',
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
          ],
        );
      },
    );
  }
}

class _DocumentalCategoryCard extends StatelessWidget {
  final DocumentalCategory category;
  final VoidCallback onTap;
  const _DocumentalCategoryCard({required this.category, required this.onTap});

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
              for (final label in const ['Registros', 'Por vencer', 'Vencidos'])
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '—',
                        style: TextStyle(
                          color: t.primarySoft,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
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
