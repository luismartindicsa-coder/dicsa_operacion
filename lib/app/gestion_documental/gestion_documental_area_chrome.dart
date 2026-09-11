import 'package:flutter/material.dart';

import '../shared/archetypes/dashboard/empty_area_dashboard.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import 'gestion_documental_calendar_page.dart';
import 'gestion_documental_catalog.dart';
import 'gestion_documental_category_page.dart';
import 'gestion_documental_theme.dart';
import 'gestion_documental_widgets.dart';

/// Shared area shell; reference: EmptyAreaDashboard / Contabilidad area chrome.
/// Child destinations replace one another, preserving the original dashboard.
class GestionDocumentalAreaShell extends StatefulWidget {
  final String current;
  final Route<dynamic>? dashboardRoute;
  final bool instantOpen;
  final Widget Function(BuildContext, void Function(String)) workspaceBuilder;

  const GestionDocumentalAreaShell({
    super.key,
    required this.current,
    required this.workspaceBuilder,
    this.dashboardRoute,
    this.instantOpen = true,
  });

  @override
  State<GestionDocumentalAreaShell> createState() =>
      _GestionDocumentalAreaShellState();
}

class _GestionDocumentalAreaShellState
    extends State<GestionDocumentalAreaShell> {
  int _navigationEpoch = 0;

  void _navigate(String destination) {
    // Recreate only the shell so its overlay closes before changing routes.
    setState(() => _navigationEpoch++);
    if (destination == widget.current) return;
    final navigator = Navigator.of(context);
    final dashboardRoute = widget.dashboardRoute ?? ModalRoute.of(context)!;
    if (destination == 'resumen') {
      navigator.popUntil((route) => identical(route, dashboardRoute));
      return;
    }
    final Widget page;
    if (destination == 'calendario') {
      page = GestionDocumentalCalendarPage(dashboardRoute: dashboardRoute);
    } else {
      final category = documentalCategories.firstWhere(
        (item) => item.key == destination,
      );
      page = GestionDocumentalCategoryPage(
        category: category,
        dashboardRoute: dashboardRoute,
      );
    }
    final route = appPageRoute<void>(page: page);
    if (widget.current == 'resumen') {
      navigator.push(route);
    } else {
      navigator.pushReplacement(route);
    }
  }

  Future<void> _returnToDirection() async {
    final navigator = Navigator.of(context);
    final dashboardRoute = widget.dashboardRoute ?? ModalRoute.of(context)!;
    navigator.popUntil((route) => identical(route, dashboardRoute));
    if (navigator.canPop()) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final destinations = [
      (key: 'resumen', title: 'Resumen', icon: Icons.space_dashboard_rounded),
      (
        key: 'calendario',
        title: 'Calendario',
        icon: Icons.calendar_month_rounded,
      ),
      for (final c in documentalCategories)
        (key: c.key, title: c.title, icon: c.icon),
    ];
    return Theme(
      data: documentalMaterialTheme(Theme.of(context)),
      child: EmptyAreaDashboardPage(
        key: ValueKey(_navigationEpoch),
        instantOpen: widget.instantOpen,
        config: documentalDashboardConfig.copyWith(
          areaItems: [
            for (final d in destinations)
              DashboardNavAction(
                title: d.title,
                subtitle: '',
                icon: d.icon,
                current: widget.current == d.key,
                onTap: () async => _navigate(d.key),
              ),
          ],
          sidePanelBuilder:
              (context, config, canReturn, accessItems, areaItems) =>
                  _DocumentalSidePanel(
                    areaItems: areaItems,
                    onReturnToDirection: canReturn ? _returnToDirection : null,
                  ),
          workspaceBuilder: (context, config, width) =>
              widget.workspaceBuilder(context, _navigate),
        ),
      ),
    );
  }
}

class _DocumentalSidePanel extends StatelessWidget {
  final List<DashboardNavAction> areaItems;
  final VoidCallback? onReturnToDirection;
  const _DocumentalSidePanel({
    required this.areaItems,
    this.onReturnToDirection,
  });

  @override
  Widget build(BuildContext context) {
    final t = AreaThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ContractGlassCard(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Gestión Documental',
                style: TextStyle(
                  color: t.onGlass,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < areaItems.length; i++) ...[
                if (i == 2) ...[
                  const SizedBox(height: 8),
                  Text(
                    'CATEGORÍAS',
                    style: TextStyle(
                      color: t.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _DocumentalNavItem(action: areaItems[i]),
                const SizedBox(height: 8),
              ],
              if (onReturnToDirection != null) ...[
                const SizedBox(height: 8),
                Divider(color: t.border.withValues(alpha: 0.25)),
                const SizedBox(height: 8),
                _DocumentalNavItem(
                  action: DashboardNavAction(
                    title: 'Volver a Dirección',
                    subtitle: '',
                    icon: Icons.arrow_back_rounded,
                    onTap: () async => onReturnToDirection!(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentalNavItem extends StatelessWidget {
  final DashboardNavAction action;
  const _DocumentalNavItem({required this.action});

  @override
  Widget build(BuildContext context) {
    final t = AreaThemeScope.of(context);
    return DocumentalActionCard(
      label: action.title,
      selected: action.current,
      onTap: action.onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Icon(action.icon, color: t.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              action.title,
              style: TextStyle(
                color: t.onGlass,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            action.current
                ? Icons.check_circle_rounded
                : Icons.chevron_right_rounded,
            color: t.primary,
            size: 18,
          ),
        ],
      ),
    );
  }
}
