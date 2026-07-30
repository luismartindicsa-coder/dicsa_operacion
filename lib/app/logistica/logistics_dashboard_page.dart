import 'package:flutter/material.dart';

import '../shared/page_routes.dart';
import '../shared/archetypes/dashboard/empty_area_dashboard.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import 'logistics_area_chrome.dart';
import 'logistics_catalog_page.dart';
import 'logistics_control_daily_page.dart';
import 'logistics_theme.dart';

class LogisticsDashboardPage extends StatelessWidget {
  final bool instantOpen;

  const LogisticsDashboardPage({super.key, this.instantOpen = false});

  static final EmptyAreaDashboardConfig _config = EmptyAreaDashboardConfig(
    dashboardLabel: 'Logística',
    sidePanelLabel: 'Logística',
    headerTitleColor: kLogisticsSilverTextPrimary,
    heroEyebrow: 'AREA LOGISTICA DICSA',
    heroTitle: 'Arranque homologado para rutas, unidades y asignación diaria.',
    heroSubtitle:
        'Logística nace sobre el arquetipo oficial de dashboard de la app para conservar shell, navegación, overlays y contrato visual antes de abrir Control Diario y pantallas operativas.',
    emptyTitle: 'Base de arranque del área',
    emptySubtitle:
        'Este dashboard debe servir como punto de entrada para validar cómo se leerá el área de Logística dentro del sistema, sin inventar interacciones nuevas ni romper la homologación transversal de la app.',
    contractTitle: 'Contrato inicial del área',
    contractSubtitle:
        'Logística debe reutilizar arquetipos homologados: dashboard para entrada del área, grid editable para Control Diario y workflow existente para leer mantenimiento.',
    contractFootnote:
        'Integraciones iniciales aprobadas: Servicios, Choferes, Unidades y Mantenimiento por FLOTILLA.',
    heroCardBorderColor: kLogisticsSilverBorder,
    heroCardGradient: kLogisticsHeroCardGradient,
    heroEyebrowColor: kLogisticsSilverTextSecondary,
    heroTitleColor: kLogisticsSilverTextPrimary,
    heroSubtitleColor: kLogisticsSilverTextSecondary,
    workspaceBodyColor: kLogisticsSilverTextSecondary,
    emptyStateSurfaceColor: kLogisticsSilverSurfaceElevated,
    emptyStateBorderColor: kLogisticsSilverBorder,
    emptyStateIconColor: kLogisticsSilverIcon,
    emptyStateBodyColor: kLogisticsSilverTextSecondary,
    contractPanelColor: kLogisticsSilverSurfaceElevated,
    contractActionColor: kLogisticsSilverSurfaceInteractive,
    contractActionHoverColor: kLogisticsSilverSurfaceHover,
    contractActionIconColor: kLogisticsSilverIcon,
    contractFootnoteColor: kLogisticsSilverTextSecondary,
    placeholderCardColor: kLogisticsSilverSurfaceElevated,
    placeholderCardIconColor: kLogisticsSilverIcon,
    placeholderCardDescriptionColor: kLogisticsSilverTextSecondary,
    placeholderCardArrowColor: kLogisticsSilverIcon,
    tokens: logisticsAreaTokens,
    ink: kLogisticsSilverTextPrimary,
    mutedInk: kLogisticsSilverTextMuted,
    heroGradient: kLogisticsHeroIconGradient,
    panelGradient: kLogisticsPanelGradient,
    accentGradient: kLogisticsAccentGradient,
    backgroundGradientColors: [
      kLogisticsSilverBackgroundTop,
      kLogisticsSilverBackgroundMiddle,
      kLogisticsSilverBackgroundBottom,
    ],
    topLeftBlobColors: [
      Color(0xC2FFFFFF),
      Color(0x82E5EAF0),
      Color(0x20BEC6CF),
    ],
    topRightBlobColors: [
      Color(0x98D9DEE5),
      Color(0x58F4F7FA),
      Color(0x16A2ACB7),
    ],
    bottomLeftBlobColors: [
      Color(0xB0FFFFFF),
      Color(0x54DEE3E9),
      Color(0x159EA8B2),
    ],
    pillarGradientColors: [
      Color(0xDCE3E9EF),
      Color(0xB9C8D1DB),
      Color(0x8899A5B0),
    ],
    areaItems: <DashboardNavAction>[],
    sidePanelBuilder: buildLogisticsDashboardSidePanel,
    showPlaceholderCards: false,
  );

  @override
  Widget build(BuildContext context) {
    Future<void> openDashboard() async {}

    Future<void> openControlDiario() async {
      await Navigator.of(context).push(
        appPageRoute(
          page: const LogisticsControlDailyPage(),
          duration: const Duration(milliseconds: 420),
          reverseDuration: const Duration(milliseconds: 360),
        ),
      );
    }

    Future<void> openUnits() async {
      _showLogisticsPhaseSnack(
        context,
        'Estado de Unidades se abrirá en la siguiente fase del área.',
      );
    }

    Future<void> openCatalogs() async {
      await Navigator.of(context).push(
        appPageRoute(
          page: const LogisticsCatalogPage(),
          duration: const Duration(milliseconds: 420),
          reverseDuration: const Duration(milliseconds: 360),
        ),
      );
    }

    Future<void> openIncidents() async {
      _showLogisticsPhaseSnack(
        context,
        'Incidencias se habilitará cuando quede validado el flujo base.',
      );
    }

    Future<void> openSavings() async {
      _showLogisticsPhaseSnack(
        context,
        'Ahorro y Planeación se conectará después del Control Diario.',
      );
    }

    return EmptyAreaDashboardPage(
      instantOpen: instantOpen,
      config: _config.copyWith(
        areaItems: [
          DashboardNavAction(
            title: kLogisticsNavDashboardLabel,
            subtitle: 'Entrada homologada del área',
            icon: Icons.local_shipping_rounded,
            current: true,
            onTap: openDashboard,
          ),
          DashboardNavAction(
            title: kLogisticsNavControlDailyLabel,
            subtitle: 'Planeación, prioridad y asignación diaria',
            icon: Icons.view_kanban_rounded,
            onTap: openControlDiario,
          ),
          DashboardNavAction(
            title: kLogisticsNavFleetStatusLabel,
            subtitle: 'Disponibilidad, FLOTILLA y bloqueos',
            icon: Icons.directions_bus_filled_rounded,
            onTap: openUnits,
          ),
          DashboardNavAction(
            title: kLogisticsNavIncidentsLabel,
            subtitle: 'Retrasos, bloqueos y reasignaciones',
            icon: Icons.report_problem_outlined,
            onTap: openIncidents,
          ),
          DashboardNavAction(
            title: kLogisticsNavCatalogsLabel,
            subtitle: 'Choferes, unidades, carga y compatibilidades',
            icon: Icons.inventory_2_outlined,
            onTap: openCatalogs,
          ),
          DashboardNavAction(
            title: kLogisticsNavSavingsLabel,
            subtitle: 'Rutas, zonas y oportunidades de optimización',
            icon: Icons.insights_outlined,
            onTap: openSavings,
          ),
        ],
        workspaceBuilder: (context, config, width) =>
            _LogisticsDashboardWorkspace(
              width: width,
              onOpenControlDiario: openControlDiario,
              onOpenUnits: openUnits,
              onOpenCatalogs: openCatalogs,
              onOpenIncidents: openIncidents,
              onOpenSavings: openSavings,
            ),
      ),
    );
  }
}

void _showLogisticsPhaseSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

class _LogisticsDashboardWorkspace extends StatelessWidget {
  final double width;
  final Future<void> Function() onOpenControlDiario;
  final Future<void> Function() onOpenUnits;
  final Future<void> Function() onOpenCatalogs;
  final Future<void> Function() onOpenIncidents;
  final Future<void> Function() onOpenSavings;

  const _LogisticsDashboardWorkspace({
    required this.width,
    required this.onOpenControlDiario,
    required this.onOpenUnits,
    required this.onOpenCatalogs,
    required this.onOpenIncidents,
    required this.onOpenSavings,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = width < 1180;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LogisticsHeroWorkspaceCard(width: width),
        const SizedBox(height: 14),
        if (isCompact) ...[
          _LogisticsModuleCard(
            icon: Icons.view_kanban_rounded,
            title: 'Control Diario',
            badge: 'Primero',
            subtitle:
                'Pantalla operativa principal para ver servicios del día, prioridad, zona, choferes y unidades disponibles.',
            outcome:
                'Debe resolver la pregunta: a quién mando, en qué unidad, a qué servicio y en qué orden.',
            onTap: onOpenControlDiario,
          ),
          const SizedBox(height: 12),
          _LogisticsModuleCard(
            icon: Icons.directions_bus_filled_rounded,
            title: 'Estado de Unidades',
            badge: 'FLOTILLA',
            subtitle:
                'Lectura de disponibilidad y mantenimiento desde el flujo ya existente del área FLOTILLA.',
            outcome:
                'Bloquea o alerta unidades antes de asignarlas dentro del Control Diario.',
            onTap: onOpenUnits,
          ),
          const SizedBox(height: 12),
          _LogisticsModuleCard(
            icon: Icons.inventory_2_outlined,
            title: 'Catálogos Operativos',
            badge: 'Base maestra',
            subtitle:
                'Choferes, tipos de unidad, tipos de carga y compatibilidades para asignar sin errores.',
            outcome:
                'Evita que Logística nazca con reglas libres o dependiente de memoria.',
            onTap: onOpenCatalogs,
          ),
          const SizedBox(height: 12),
          _LogisticsModuleCard(
            icon: Icons.report_problem_outlined,
            title: 'Incidencias',
            badge: 'Seguimiento',
            subtitle:
                'Retrasos, material no listo, falla mecánica, cambio de unidad y reprogramación.',
            outcome:
                'Da visibilidad operativa y evita perder control del día cuando algo cambia.',
            onTap: onOpenIncidents,
          ),
          const SizedBox(height: 12),
          _LogisticsModuleCard(
            icon: Icons.insights_outlined,
            title: 'Ahorro y Planeación',
            badge: 'Segunda capa',
            subtitle:
                'Zona, duplicidad de viajes, combinación de servicios y uso real de unidades.',
            outcome:
                'Convierte el histórico operativo en ahorro medible sin complicar la captura diaria.',
            onTap: onOpenSavings,
          ),
        ] else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _LogisticsModuleCard(
                width: (width - 12) / 2,
                icon: Icons.view_kanban_rounded,
                title: 'Control Diario',
                badge: 'Primero',
                subtitle:
                    'Pantalla operativa principal para ver servicios del día, prioridad, zona, choferes y unidades disponibles.',
                outcome:
                    'Debe resolver la pregunta: a quién mando, en qué unidad, a qué servicio y en qué orden.',
                onTap: onOpenControlDiario,
              ),
              _LogisticsModuleCard(
                width: (width - 12) / 2,
                icon: Icons.directions_bus_filled_rounded,
                title: 'Estado de Unidades',
                badge: 'FLOTILLA',
                subtitle:
                    'Lectura de disponibilidad y mantenimiento desde el flujo ya existente del área FLOTILLA.',
                outcome:
                    'Bloquea o alerta unidades antes de asignarlas dentro del Control Diario.',
                onTap: onOpenUnits,
              ),
              _LogisticsModuleCard(
                width: (width - 24) / 3,
                icon: Icons.inventory_2_outlined,
                title: 'Catálogos Operativos',
                badge: 'Base maestra',
                subtitle:
                    'Choferes, tipos de unidad, tipos de carga y compatibilidades para asignar sin errores.',
                outcome:
                    'Evita que Logística nazca con reglas libres o dependiente de memoria.',
                onTap: onOpenCatalogs,
              ),
              _LogisticsModuleCard(
                width: (width - 24) / 3,
                icon: Icons.report_problem_outlined,
                title: 'Incidencias',
                badge: 'Seguimiento',
                subtitle:
                    'Retrasos, material no listo, falla mecánica, cambio de unidad y reprogramación.',
                outcome:
                    'Da visibilidad operativa y evita perder control del día cuando algo cambia.',
                onTap: onOpenIncidents,
              ),
              _LogisticsModuleCard(
                width: (width - 24) / 3,
                icon: Icons.insights_outlined,
                title: 'Ahorro y Planeación',
                badge: 'Segunda capa',
                subtitle:
                    'Zona, duplicidad de viajes, combinación de servicios y uso real de unidades.',
                outcome:
                    'Convierte el histórico operativo en ahorro medible sin complicar la captura diaria.',
                onTap: onOpenSavings,
              ),
            ],
          ),
      ],
    );
  }
}

class _LogisticsHeroWorkspaceCard extends StatelessWidget {
  final double width;

  const _LogisticsHeroWorkspaceCard({required this.width});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final isCompact = width < 1120;
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ruta de arranque aprobada',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: tokens.onGlass,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Logística arranca como área formal desde Dirección, pero debe heredar el mismo lenguaje de dashboard, overlay y navegación del sistema antes de abrir sus pantallas operativas.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: tokens.onGlass.withValues(alpha: 0.84),
            height: 1.45,
          ),
        ),
      ],
    );
    final capsule = Container(
      width: isCompact ? double.infinity : 248,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: kLogisticsCapsuleGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kLogisticsSilverDivider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.52),
            blurRadius: 10,
            offset: const Offset(0, -1),
          ),
          BoxShadow(
            color: kLogisticsSilverGlow.withValues(alpha: 0.46),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Prioridad visual',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              color: kLogisticsSilverTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Primero validar lectura, navegación e interacción del área. Después conectamos Control Diario y catálogos reales.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kLogisticsSilverTextSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );

    return ContractGlassCard(
      blurSigma: 7,
      elevation: 20,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [header, const SizedBox(height: 12), capsule],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: header),
                const SizedBox(width: 12),
                capsule,
              ],
            ),
    );
  }
}

class _LogisticsModuleCard extends StatefulWidget {
  final double? width;
  final IconData icon;
  final String title;
  final String badge;
  final String subtitle;
  final String outcome;
  final Future<void> Function() onTap;

  const _LogisticsModuleCard({
    this.width,
    required this.icon,
    required this.title,
    required this.badge,
    required this.subtitle,
    required this.outcome,
    required this.onTap,
  });

  @override
  State<_LogisticsModuleCard> createState() => _LogisticsModuleCardState();
}

class _LogisticsModuleCardState extends State<_LogisticsModuleCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: _hovered ? 1.012 : 1,
        child: SizedBox(
          width: widget.width,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () async => widget.onTap(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
                child: ContractGlassCard(
                  padding: EdgeInsets.zero,
                  blurSigma: 7,
                  elevation: _hovered ? 24 : 18,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: kLogisticsModuleGradient,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: tokens.border.withValues(
                          alpha: _hovered ? 0.88 : 0.72,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: _hovered ? 0.10 : 0.07,
                          ),
                          blurRadius: _hovered ? 24 : 18,
                          offset: Offset(0, _hovered ? 14 : 10),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(
                            alpha: _hovered ? 0.64 : 0.48,
                          ),
                          blurRadius: _hovered ? 14 : 10,
                          offset: const Offset(0, -2),
                        ),
                        BoxShadow(
                          color: kLogisticsSilverGlowEdge.withValues(
                            alpha: _hovered ? 0.42 : 0.26,
                          ),
                          blurRadius: _hovered ? 22 : 16,
                          spreadRadius: _hovered ? 1.5 : 0.4,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: kLogisticsHeroIconGradient,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: tokens.border.withValues(alpha: 0.66),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 8),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.52),
                                    blurRadius: 10,
                                    offset: const Offset(0, -1),
                                  ),
                                  BoxShadow(
                                    color: kLogisticsSilverGlow.withValues(
                                      alpha: 0.34,
                                    ),
                                    blurRadius: 14,
                                  ),
                                ],
                              ),
                              child: Icon(
                                widget.icon,
                                color: kLogisticsSilverIcon,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: kLogisticsCapsuleGradient,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: kLogisticsSilverDivider,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.04,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 6),
                                        ),
                                        BoxShadow(
                                          color: kLogisticsSilverGlow
                                              .withValues(alpha: 0.26),
                                          blurRadius: 14,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      widget.badge,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                        color: kLogisticsSilverTextSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    widget.title,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: tokens.onGlass,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: tokens.onGlass.withValues(alpha: 0.86),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          decoration: BoxDecoration(
                            gradient: kLogisticsCapsuleGradient,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: kLogisticsSilverDivider),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 6),
                              ),
                              BoxShadow(
                                color: kLogisticsSilverGlow.withValues(
                                  alpha: 0.24,
                                ),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                          child: Text(
                            widget.outcome,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: tokens.onGlass.withValues(alpha: 0.80),
                              height: 1.35,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              'Abrir siguiente fase',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: kLogisticsSilverTextSecondary,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: kLogisticsSilverIcon,
                              size: 20,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
