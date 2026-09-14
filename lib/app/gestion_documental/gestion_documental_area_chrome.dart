import 'dart:ui';

import 'package:flutter/material.dart';

import '../shared/archetypes/dashboard/empty_area_dashboard.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import 'gestion_documental_calendar_page.dart';
import 'gestion_documental_catalog.dart';
import 'gestion_documental_category_page.dart';
import 'gestion_documental_theme.dart';

/// Shared area shell; reference: EmptyAreaDashboard / Finanzas navigation contract.
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
    if (destination == 'dashboard') {
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
    if (widget.current == 'dashboard') {
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
      (
        key: 'dashboard',
        title: 'Dashboard Gestión Documental',
        subtitle: 'Documentos, trámites y vigencias',
        icon: Icons.folder_copy_rounded,
      ),
      (
        key: 'calendario',
        title: 'Calendario',
        subtitle: 'Vencimientos y obligaciones',
        icon: Icons.calendar_month_rounded,
      ),
      for (final c in documentalCategories)
        (
          key: c.key,
          title: c.title,
          subtitle: c.documentTypes.take(2).join(' · '),
          icon: c.icon,
        ),
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
                subtitle: d.subtitle,
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
    final tokens = AreaThemeScope.of(context);
    return SizedBox(
      width: 320,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: _DocumentalNavigationGlass(
          borderRadius: BorderRadius.circular(28),
          blurSigma: 30,
          fillColor: tokens.glassSurface.withValues(alpha: 0.82),
          borderColor: tokens.border.withValues(alpha: 0.92),
          shadowColor: Colors.black.withValues(alpha: 0.34),
          edgeHighlightColor: tokens.primarySoft.withValues(alpha: 0.18),
          bevelShadowColor: Colors.black.withValues(alpha: 0.20),
          glowColor: tokens.glow.withValues(alpha: 0.42),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Navegación Gestión Documental',
                  style: TextStyle(
                    color: tokens.primarySoft,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Módulos del área y accesos habilitados',
                  style: TextStyle(
                    color: tokens.primarySoft.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                _DocumentalSidePanelBlock(
                  icon: Icons.event_note_rounded,
                  title: 'Seguimiento',
                  children: [areaItems[1]],
                ),
                const SizedBox(height: 12),
                _DocumentalSidePanelBlock(
                  icon: Icons.folder_copy_rounded,
                  title: 'Expedientes',
                  children: areaItems.skip(2).toList(growable: false),
                ),
                const SizedBox(height: 12),
                _DocumentalSidePanelBlock(
                  icon: Icons.apps_rounded,
                  title: 'Accesos',
                  children: [
                    areaItems.first,
                    if (onReturnToDirection != null)
                      DashboardNavAction(
                        title: 'Dashboard Dirección',
                        subtitle: 'Vista ejecutiva multiarea',
                        icon: Icons.space_dashboard_rounded,
                        onTap: () async => onReturnToDirection!(),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Cloned from FinanzasAreaSidePanel: only area colors, labels and destinations differ.
class _DocumentalSidePanelBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<DashboardNavAction> children;

  const _DocumentalSidePanelBlock({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return _DocumentalNavigationGlass(
      borderRadius: BorderRadius.circular(20),
      blurSigma: 24,
      fillColor: tokens.glassSurface.withValues(alpha: 0.68),
      borderColor: tokens.border.withValues(alpha: 0.80),
      shadowColor: Colors.black.withValues(alpha: 0.24),
      edgeHighlightColor: tokens.primarySoft.withValues(alpha: 0.14),
      bevelShadowColor: Colors.black.withValues(alpha: 0.18),
      glowColor: tokens.glow.withValues(alpha: 0.22),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: tokens.primarySoft),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: tokens.primarySoft,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < children.length; i++) ...[
            _DocumentalSidePanelAction(entry: children[i]),
            if (i != children.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _DocumentalSidePanelAction extends StatefulWidget {
  final DashboardNavAction entry;

  const _DocumentalSidePanelAction({required this.entry});

  @override
  State<_DocumentalSidePanelAction> createState() =>
      _DocumentalSidePanelActionState();
}

class _DocumentalSidePanelActionState
    extends State<_DocumentalSidePanelAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final highlighted = widget.entry.current || _hovered;
    final current = widget.entry.current;
    final gradient = current
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tokens.primaryStrong, tokens.accent],
          )
        : null;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: widget.entry.current ? null : widget.entry.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            gradient: gradient,
            color: current
                ? null
                : highlighted
                ? tokens.primary.withValues(alpha: 0.14)
                : tokens.glassSurface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: current
                  ? tokens.primary.withValues(alpha: 0.70)
                  : highlighted
                  ? tokens.border.withValues(alpha: 0.45)
                  : tokens.border.withValues(alpha: 0.72),
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: current ? 28 : 18,
                offset: const Offset(0, 10),
                color: Colors.black.withValues(alpha: current ? 0.28 : 0.18),
              ),
              BoxShadow(
                blurRadius: current ? 28 : 16,
                spreadRadius: current ? 1 : 0,
                color: tokens.glow.withValues(alpha: current ? 0.52 : 0.20),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                widget.entry.icon,
                size: 18,
                color: current ? Colors.white : tokens.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.entry.title,
                      style: TextStyle(
                        color: current ? Colors.white : tokens.onGlass,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.entry.subtitle,
                      style: TextStyle(
                        color: current
                            ? Colors.white.withValues(alpha: 0.88)
                            : tokens.onGlass.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.entry.current)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: highlighted
                      ? tokens.primary
                      : tokens.onGlass.withValues(alpha: 0.78),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentalNavigationGlass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double blurSigma;
  final Color fillColor;
  final Color borderColor;
  final Color shadowColor;
  final Color edgeHighlightColor;
  final Color bevelShadowColor;
  final Color glowColor;

  const _DocumentalNavigationGlass({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.blurSigma = 22,
    required this.fillColor,
    required this.borderColor,
    required this.shadowColor,
    required this.edgeHighlightColor,
    required this.bevelShadowColor,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: borderRadius,
            border: Border.all(color: borderColor),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tokens.primaryStrong.withValues(alpha: 0.10),
                tokens.primary.withValues(alpha: 0.08),
                tokens.accent.withValues(alpha: 0.10),
                Colors.transparent,
              ],
              stops: const [0.0, 0.16, 0.48, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 50,
                offset: const Offset(0, 18),
                color: shadowColor,
              ),
              BoxShadow(
                blurRadius: 32,
                spreadRadius: 1,
                offset: const Offset(0, 0),
                color: glowColor,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: borderRadius,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          edgeHighlightColor,
                          tokens.primary.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.16, 0.52],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                top: 8,
                height: 56 * 0.34,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          tokens.primary.withValues(alpha: 0.10),
                          tokens.primaryStrong.withValues(alpha: 0.04),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: borderRadius,
                      boxShadow: [
                        BoxShadow(
                          color: edgeHighlightColor.withValues(alpha: 0.18),
                          blurRadius: 0,
                          spreadRadius: 0.6,
                        ),
                        BoxShadow(
                          color: bevelShadowColor.withValues(alpha: 0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}
