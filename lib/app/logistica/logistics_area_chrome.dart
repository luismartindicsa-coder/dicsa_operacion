import 'package:flutter/material.dart';

import '../shared/archetypes/dashboard/empty_area_dashboard.dart';
import '../services/services_visual_mode.dart';
import 'logistics_theme.dart';

const double kLogisticsSideMenuWidth = 332.0;

const String kLogisticsNavDashboardLabel = 'Dashboard Logística';
const String kLogisticsNavControlDailyLabel = 'Control Diario';
const String kLogisticsNavFleetStatusLabel = 'Estado de Unidades';
const String kLogisticsNavIncidentsLabel = 'Incidencias';
const String kLogisticsNavCatalogsLabel = 'Catálogos Operativos';
const String kLogisticsNavSavingsLabel = 'Ahorro y Planeación';
const String kLogisticsNavDirectionDashboardLabel = 'Dashboard Dirección';

class LogisticsAreaNavEntry {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool current;
  final Future<void> Function()? onTap;

  const LogisticsAreaNavEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.current = false,
    this.onTap,
  });
}

class LogisticsAreaNavSection {
  final IconData icon;
  final String title;
  final List<LogisticsAreaNavEntry> children;

  const LogisticsAreaNavSection({
    required this.icon,
    required this.title,
    required this.children,
  });
}

List<LogisticsAreaNavSection> _buildLogisticsAreaSections({
  required String currentLabel,
  required bool canReturnToDirection,
  required ValueChanged<String> onNavigate,
}) {
  LogisticsAreaNavEntry buildEntry({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final current = currentLabel == title;
    return LogisticsAreaNavEntry(
      icon: icon,
      title: title,
      subtitle: subtitle,
      current: current,
      onTap: current ? null : () async => onNavigate(title),
    );
  }

  return <LogisticsAreaNavSection>[
    LogisticsAreaNavSection(
      icon: Icons.route_rounded,
      title: 'Ejecución',
      children: [
        buildEntry(
          icon: Icons.view_kanban_rounded,
          title: kLogisticsNavControlDailyLabel,
          subtitle: 'Planeación, prioridad y asignación',
        ),
        buildEntry(
          icon: Icons.directions_bus_filled_rounded,
          title: kLogisticsNavFleetStatusLabel,
          subtitle: 'Disponibilidad, bloqueos y FLOTILLA',
        ),
        buildEntry(
          icon: Icons.report_problem_outlined,
          title: kLogisticsNavIncidentsLabel,
          subtitle: 'Retrasos, cambios y reprogramación',
        ),
      ],
    ),
    LogisticsAreaNavSection(
      icon: Icons.tune_rounded,
      title: 'Planeación',
      children: [
        buildEntry(
          icon: Icons.inventory_2_outlined,
          title: kLogisticsNavCatalogsLabel,
          subtitle: 'Choferes, unidades y compatibilidades',
        ),
        buildEntry(
          icon: Icons.insights_outlined,
          title: kLogisticsNavSavingsLabel,
          subtitle: 'Rutas, zonas y oportunidades',
        ),
      ],
    ),
    if (canReturnToDirection)
      LogisticsAreaNavSection(
        icon: Icons.apps_rounded,
        title: 'Accesos',
        children: [
          buildEntry(
            icon: Icons.local_shipping_rounded,
            title: kLogisticsNavDashboardLabel,
            subtitle: 'Entrada homologada del área',
          ),
          buildEntry(
            icon: Icons.space_dashboard_rounded,
            title: kLogisticsNavDirectionDashboardLabel,
            subtitle: 'Vista ejecutiva multiarea',
          ),
        ],
      ),
    if (!canReturnToDirection)
      LogisticsAreaNavSection(
        icon: Icons.apps_rounded,
        title: 'Accesos',
        children: [
          buildEntry(
            icon: Icons.local_shipping_rounded,
            title: kLogisticsNavDashboardLabel,
            subtitle: 'Entrada homologada del área',
          ),
        ],
      ),
  ];
}

DashboardNavAction? _findDashboardAction(
  Iterable<DashboardNavAction> actions,
  String title,
) {
  for (final action in actions) {
    if (action.title == title) return action;
  }
  return null;
}

LogisticsAreaNavEntry? _entryFromDashboardAction(
  Iterable<DashboardNavAction> actions,
  String title,
) {
  final action = _findDashboardAction(actions, title);
  if (action == null) return null;
  return LogisticsAreaNavEntry(
    icon: action.icon,
    title: action.title,
    subtitle: action.subtitle,
    current: action.current,
    onTap: action.current ? null : action.onTap,
  );
}

String _resolveDashboardCurrentLabel(List<DashboardNavAction> areaItems) {
  for (final action in areaItems) {
    if (action.current) return action.title;
  }
  if (areaItems.isNotEmpty) return areaItems.first.title;
  return kLogisticsNavDashboardLabel;
}

List<LogisticsAreaNavSection> _buildDashboardSections({
  required List<DashboardNavAction> areaItems,
  required List<DashboardNavAction> accessItems,
}) {
  final dashboard = _entryFromDashboardAction(
    areaItems,
    kLogisticsNavDashboardLabel,
  );
  final controlDaily = _entryFromDashboardAction(
    areaItems,
    kLogisticsNavControlDailyLabel,
  );
  final fleetStatus = _entryFromDashboardAction(
    areaItems,
    kLogisticsNavFleetStatusLabel,
  );
  final incidents = _entryFromDashboardAction(
    areaItems,
    kLogisticsNavIncidentsLabel,
  );
  final catalogs = _entryFromDashboardAction(
    areaItems,
    kLogisticsNavCatalogsLabel,
  );
  final savings = _entryFromDashboardAction(
    areaItems,
    kLogisticsNavSavingsLabel,
  );
  final directionDashboard = _entryFromDashboardAction(
    accessItems,
    kLogisticsNavDirectionDashboardLabel,
  );

  return <LogisticsAreaNavSection>[
    LogisticsAreaNavSection(
      icon: Icons.route_rounded,
      title: 'Ejecución',
      children: [?controlDaily, ?fleetStatus, ?incidents],
    ),
    LogisticsAreaNavSection(
      icon: Icons.tune_rounded,
      title: 'Planeación',
      children: [?catalogs, ?savings],
    ),
    LogisticsAreaNavSection(
      icon: Icons.apps_rounded,
      title: 'Accesos',
      children: [?dashboard, ?directionDashboard],
    ),
  ];
}

Widget buildLogisticsDashboardSidePanel(
  BuildContext context,
  EmptyAreaDashboardConfig config,
  bool canReturnToDirection,
  List<DashboardNavAction> accessItems,
  List<DashboardNavAction> areaItems,
) {
  return LogisticsAreaSidePanel(
    currentLabel: _resolveDashboardCurrentLabel(areaItems),
    canReturnToDirection: canReturnToDirection,
    sections: _buildDashboardSections(
      areaItems: areaItems,
      accessItems: accessItems,
    ),
  );
}

class LogisticsAreaSidePanel extends StatelessWidget {
  final String currentLabel;
  final bool canReturnToDirection;
  final ValueChanged<String>? onNavigate;
  final String title;
  final String subtitle;
  final List<LogisticsAreaNavSection>? sections;

  const LogisticsAreaSidePanel({
    super.key,
    required this.currentLabel,
    required this.canReturnToDirection,
    this.onNavigate,
    this.title = 'Navegación Logística',
    this.subtitle = 'Módulos del área y accesos habilitados',
    this.sections,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedSections =
        (sections ??
                _buildLogisticsAreaSections(
                  currentLabel: currentLabel,
                  canReturnToDirection: canReturnToDirection,
                  onNavigate: onNavigate!,
                ))
            .where((section) => section.children.isNotEmpty)
            .toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaQuery = MediaQuery.of(context);
        final fallbackMaxHeight =
            (mediaQuery.size.height -
                    mediaQuery.padding.top -
                    mediaQuery.padding.bottom -
                    112)
                .clamp(320.0, mediaQuery.size.height)
                .toDouble();
        final panelMaxHeight =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : fallbackMaxHeight;

        return SizedBox(
          width: 320,
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: panelMaxHeight),
              child: _LogisticsPanelSurface(
                child: ScrollConfiguration(
                  behavior: const MaterialScrollBehavior().copyWith(
                    scrollbars: false,
                  ),
                  child: SingleChildScrollView(
                    primary: false,
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1C222A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF555E68),
                          ),
                        ),
                        const SizedBox(height: 14),
                        for (
                          var index = 0;
                          index < resolvedSections.length;
                          index++
                        ) ...[
                          _LogisticsSidePanelBlock(
                            icon: resolvedSections[index].icon,
                            title: resolvedSections[index].title,
                            children: resolvedSections[index].children,
                          ),
                          if (index != resolvedSections.length - 1)
                            const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LogisticsSidePanelBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<LogisticsAreaNavEntry> children;

  const _LogisticsSidePanelBlock({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return _LogisticsPanelSurface(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: kLogisticsSilverIcon),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: kLogisticsSilverTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < children.length; index++) ...[
            _LogisticsSidePanelTile(entry: children[index]),
            if (index != children.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _LogisticsSidePanelTile extends StatefulWidget {
  final LogisticsAreaNavEntry entry;

  const _LogisticsSidePanelTile({required this.entry});

  @override
  State<_LogisticsSidePanelTile> createState() =>
      _LogisticsSidePanelTileState();
}

class _LogisticsSidePanelTileState extends State<_LogisticsSidePanelTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = ServicesVisualPalette.of(context);
    final current = widget.entry.current;
    final highlighted = current || _hovered;
    final gradient = current
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF8B939C),
              kLogisticsSilverFooterTop,
              kLogisticsSilverFooterBottom,
            ],
          )
        : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: current ? null : widget.entry.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              gradient: gradient,
              color: current
                  ? null
                  : highlighted
                  ? kLogisticsSilverSurfaceHover
                  : kLogisticsSilverSurfaceElevated.withValues(alpha: 0.76),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: current
                    ? kLogisticsSilverBorderLight
                    : highlighted
                    ? kLogisticsSilverBorder
                    : kLogisticsSilverBorder.withValues(alpha: 0.72),
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: current ? 28 : 16,
                  offset: const Offset(0, 10),
                  color: Colors.black.withValues(alpha: current ? 0.20 : 0.12),
                ),
                if (current || highlighted)
                  BoxShadow(
                    blurRadius: current ? 24 : 16,
                    spreadRadius: current ? 1 : 0,
                    color: palette.glow.withValues(
                      alpha: current ? 0.34 : 0.18,
                    ),
                  ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  widget.entry.icon,
                  size: 18,
                  color: current ? Colors.white : kLogisticsSilverIcon,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.entry.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: current
                              ? Colors.white
                              : kLogisticsSilverTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.entry.subtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: current
                              ? Colors.white.withValues(alpha: 0.88)
                              : kLogisticsSilverTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  current
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: current
                      ? Colors.white
                      : highlighted
                      ? kLogisticsSilverTextPrimary
                      : kLogisticsSilverTextMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogisticsPanelSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _LogisticsPanelSurface({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(14, 14, 14, 14),
  });

  @override
  Widget build(BuildContext context) {
    final palette = ServicesVisualPalette.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F9),
        gradient: palette.glassCardGradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFFFFFFF)),
        boxShadow: [
          BoxShadow(
            blurRadius: 28,
            color: const Color(0x2418212A),
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            blurRadius: 20,
            color: palette.glow.withValues(alpha: 0.16),
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
