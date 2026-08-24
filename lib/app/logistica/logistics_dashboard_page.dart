import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../management_reports/management_reports_registry.dart';
import '../management_reports/management_reports_widgets.dart';
import '../management_reports/management_supervision_page.dart';
import '../shared/app_error_reporter.dart';
import '../shared/page_routes.dart';
import '../shared/archetypes/dashboard/empty_area_dashboard.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import 'logistics_area_chrome.dart';
import 'logistics_catalog_page.dart';
import 'logistics_control_daily_page.dart';
import 'logistics_diesel_page.dart';
import 'logistics_diesel_store.dart';
import 'logistics_gasoline_page.dart';
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

    Future<void> openDiesel() async {
      await Navigator.of(context).push(
        appPageRoute(
          page: const LogisticsDieselPage(),
          duration: const Duration(milliseconds: 420),
          reverseDuration: const Duration(milliseconds: 360),
        ),
      );
    }

    Future<void> openGasoline() async {
      await Navigator.of(context).push(
        appPageRoute(
          page: const LogisticsGasolinePage(),
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

    Future<void> openManagementSupervision() async {
      await Navigator.of(context).push(
        appPageRoute(
          page: const ManagementSupervisionPage(instantOpen: true),
          duration: const Duration(milliseconds: 320),
          reverseDuration: const Duration(milliseconds: 240),
        ),
      );
    }

    return EmptyAreaDashboardPage(
      instantOpen: instantOpen,
      config: _config.copyWith(
        showHeroPanel: false,
        showContractPanel: false,
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
            title: kLogisticsNavDieselLabel,
            subtitle: 'Compras, solicitudes y saldo por unidad',
            icon: Icons.local_gas_station_rounded,
            onTap: openDiesel,
          ),
          DashboardNavAction(
            title: kLogisticsNavGasolineLabel,
            subtitle: 'Cargas directas en gasolinera por operador y unidad',
            icon: Icons.local_gas_station_outlined,
            onTap: openGasoline,
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
              onOpenDiesel: openDiesel,
              onOpenGasoline: openGasoline,
              onOpenIncidents: openIncidents,
              onOpenSavings: openSavings,
              onOpenSupervisionHub: openManagementSupervision,
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

bool _usesGerenciaExecutiveTheme(BuildContext context) =>
    AreaThemeScope.of(context).darkGlass;

LinearGradient _logisticsExecutiveSurfaceGradient(BuildContext context) {
  if (_usesGerenciaExecutiveTheme(context)) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xE62A0D14), Color(0xE61A070D)],
    );
  }
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withValues(alpha: 0.48),
      const Color(0xFFF2F4F7).withValues(alpha: 0.76),
      const Color(0xFFD8DDE3).withValues(alpha: 0.62),
    ],
  );
}

LinearGradient _logisticsExecutiveModuleGradient(BuildContext context) {
  if (_usesGerenciaExecutiveTheme(context)) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xE6331019), Color(0xE61F080F)],
    );
  }
  return kLogisticsModuleGradient;
}

LinearGradient _logisticsExecutiveCapsuleGradient(BuildContext context) {
  if (_usesGerenciaExecutiveTheme(context)) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0x994A1520), Color(0xCC6A2130)],
    );
  }
  return kLogisticsCapsuleGradient;
}

Color _logisticsExecutiveBorder(BuildContext context, {double alpha = 1}) {
  final tokens = AreaThemeScope.of(context);
  return (_usesGerenciaExecutiveTheme(context)
          ? tokens.border
          : kLogisticsSilverBorder)
      .withValues(alpha: alpha);
}

Color _logisticsExecutiveMutedText(
  BuildContext context, {
  double alpha = 0.76,
}) {
  final tokens = AreaThemeScope.of(context);
  return (_usesGerenciaExecutiveTheme(context)
          ? tokens.onGlass
          : kLogisticsSilverTextSecondary)
      .withValues(alpha: alpha);
}

class LogisticsManagementExecutiveSection extends StatelessWidget {
  final Future<void> Function()? onOpenControlDiario;
  final Future<void> Function()? onOpenDiesel;
  final Future<void> Function()? onOpenGasoline;

  const LogisticsManagementExecutiveSection({
    super.key,
    this.onOpenControlDiario,
    this.onOpenDiesel,
    this.onOpenGasoline,
  });

  @override
  Widget build(BuildContext context) {
    final parentTokens = AreaThemeScope.of(context);
    return AreaThemeScope(
      // Gerencia consumes these widgets as an executive surface, while the
      // Logistica dashboard keeps its own silver operational identity.
      tokens: parentTokens.darkGlass ? parentTokens : logisticsAreaTokens,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LogisticsWorkspaceGroup(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                final summaryHeight = availableWidth < 1080 ? 404.0 : 364.0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LogisticsDieselStatusStrip(onOpenSource: onOpenDiesel),
                    const SizedBox(height: 14),
                    _LogisticsWeeklyDriverCharts(
                      width: availableWidth,
                      preferSideBySide: availableWidth >= 1520,
                      chartHeight: availableWidth >= 1520
                          ? 472
                          : availableWidth >= 1180
                          ? 438
                          : 408,
                      onOpenDieselSource: onOpenDiesel,
                      onOpenGasolineSource: onOpenGasoline,
                      onOpenServicesSource: onOpenControlDiario,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: summaryHeight,
                      child: _LogisticsServicesSummaryPanel(
                        onOpenSource: onOpenControlDiario,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (onOpenControlDiario != null) ...[
            const SizedBox(height: 14),
            _LogisticsWorkspaceGroup(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: _LogisticsModuleCard(
                icon: Icons.view_kanban_rounded,
                title: 'Control Diario',
                badge: 'Logística',
                subtitle:
                    'Pantalla operativa principal para ver servicios del día, prioridad, zona, choferes y unidades disponibles.',
                outcome:
                    'Resuelve la lectura diaria de asignación para Gerencia sin salir del frente ejecutivo.',
                onTap: onOpenControlDiario!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LogisticsDashboardWorkspace extends StatelessWidget {
  final double width;
  final Future<void> Function() onOpenControlDiario;
  final Future<void> Function() onOpenUnits;
  final Future<void> Function() onOpenCatalogs;
  final Future<void> Function() onOpenDiesel;
  final Future<void> Function() onOpenGasoline;
  final Future<void> Function() onOpenIncidents;
  final Future<void> Function() onOpenSavings;
  final Future<void> Function() onOpenSupervisionHub;

  const _LogisticsDashboardWorkspace({
    required this.width,
    required this.onOpenControlDiario,
    required this.onOpenUnits,
    required this.onOpenCatalogs,
    required this.onOpenDiesel,
    required this.onOpenGasoline,
    required this.onOpenIncidents,
    required this.onOpenSavings,
    required this.onOpenSupervisionHub,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final isCompact = width < 1180;
    final moduleGridWidth = math.max(0.0, width - 32);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LogisticsWorkspaceGroup(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final summaryHeight = availableWidth < 1080 ? 404.0 : 364.0;
              final summaryPanel = SizedBox(
                height: summaryHeight,
                child: _LogisticsServicesSummaryPanel(
                  onOpenSource: onOpenControlDiario,
                ),
              );
              final weeklyPanel = _LogisticsWeeklyDriverCharts(
                width: availableWidth,
                preferSideBySide: availableWidth >= 1520,
                chartHeight: availableWidth >= 1520
                    ? 472
                    : availableWidth >= 1180
                    ? 438
                    : 408,
                onOpenDieselSource: onOpenDiesel,
                onOpenGasolineSource: onOpenGasoline,
                onOpenServicesSource: onOpenControlDiario,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LogisticsDieselStatusStrip(onOpenSource: onOpenDiesel),
                  const SizedBox(height: 14),
                  weeklyPanel,
                  const SizedBox(height: 14),
                  summaryPanel,
                  const SizedBox(height: 14),
                  ManagementAreaReportPanel(
                    areaKey: ManagementAreaKey.logistica,
                    subtitleOverride:
                        'El encargado de Logística debe generar aquí su corte semanal, estudiarlo antes de la junta y llegar con explicación de costos, viajes y complicaciones.',
                    showOpenHubButton: true,
                    showReportActions: false,
                    onOpenSupervisionHub: onOpenSupervisionHub,
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        _LogisticsWorkspaceGroup(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Accesos del área',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: tokens.onGlass,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Entradas homologadas para bajar al trabajo diario del área.',
                      style: TextStyle(
                        fontSize: 12.8,
                        fontWeight: FontWeight.w700,
                        color: tokens.onGlass.withValues(alpha: 0.76),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
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
                  icon: Icons.local_gas_station_rounded,
                  title: 'Consumo de Diesel',
                  badge: 'Combustible',
                  subtitle:
                      'Fecha, operador, unidad, litros comprados, litros solicitados y saldo operativo.',
                  outcome:
                      'Hace visible el consumo diario para empezar a medir ahorro real por combustible.',
                  onTap: onOpenDiesel,
                ),
                const SizedBox(height: 12),
                _LogisticsModuleCard(
                  icon: Icons.local_gas_station_outlined,
                  title: 'Control de Gasolina',
                  badge: 'Gasolinera',
                  subtitle:
                      'Fecha, operador, unidad y litros cargados en compras directas fuera del tanque interno.',
                  outcome:
                      'Separa el consumo directo en gasolinera para medirlo sin mezclarlo con el saldo operativo de diesel.',
                  onTap: onOpenGasoline,
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
                      width: (moduleGridWidth - 12) / 2,
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
                      width: (moduleGridWidth - 12) / 2,
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
                      width: (moduleGridWidth - 24) / 3,
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
                      width: (moduleGridWidth - 24) / 3,
                      icon: Icons.local_gas_station_rounded,
                      title: 'Consumo de Diesel',
                      badge: 'Combustible',
                      subtitle:
                          'Fecha, operador, unidad, litros comprados, litros solicitados y saldo operativo.',
                      outcome:
                          'Hace visible el consumo diario para empezar a medir ahorro real por combustible.',
                      onTap: onOpenDiesel,
                    ),
                    _LogisticsModuleCard(
                      width: (moduleGridWidth - 24) / 3,
                      icon: Icons.local_gas_station_outlined,
                      title: 'Control de Gasolina',
                      badge: 'Gasolinera',
                      subtitle:
                          'Fecha, operador, unidad y litros cargados en compras directas fuera del tanque interno.',
                      outcome:
                          'Separa el consumo directo en gasolinera para medirlo sin mezclarlo con el saldo operativo de diesel.',
                      onTap: onOpenGasoline,
                    ),
                    _LogisticsModuleCard(
                      width: (moduleGridWidth - 24) / 3,
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
                      width: (moduleGridWidth - 24) / 3,
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
          ),
        ),
      ],
    );
  }
}

class _LogisticsWorkspaceGroup extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _LogisticsWorkspaceGroup({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(14, 14, 14, 16),
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final executive = tokens.darkGlass;
    return Container(
      decoration: BoxDecoration(
        gradient: _logisticsExecutiveSurfaceGradient(context),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: executive
              ? tokens.border.withValues(alpha: 0.52)
              : kLogisticsSilverBorder.withValues(alpha: 0.56),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: executive ? 0.24 : 0.05),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
          if (!executive)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.50),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
        ],
      ),
      padding: padding,
      child: child,
    );
  }
}

class _LogisticsDieselStatusStrip extends StatefulWidget {
  final Future<void> Function()? onOpenSource;

  const _LogisticsDieselStatusStrip({this.onOpenSource});

  @override
  State<_LogisticsDieselStatusStrip> createState() =>
      _LogisticsDieselStatusStripState();
}

class _LogisticsDieselStatusStripState
    extends State<_LogisticsDieselStatusStrip>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _refreshing = false;
  bool _pendingReload = false;
  double _totalPurchased = 0;
  double _totalRequested = 0;
  double _currentBalance = 0;
  DateTime? _lastBalanceDate;
  Timer? _timer;
  RealtimeChannel? _dieselRealtime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload(showLoader: true);
    _setupRealtime();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _dieselRealtime?.unsubscribe();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _requestReload();
    }
  }

  void _setupRealtime() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 18), (_) {
      _requestReload();
    });

    _dieselRealtime?.unsubscribe();
    _dieselRealtime = Supabase.instance.client
        .channel('logistics-dashboard-diesel-strip')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'logistics_diesel_consumption',
          callback: (_) => _requestReload(),
        )
        .subscribe();
  }

  void _requestReload() {
    if (!mounted) return;
    if (_refreshing) {
      _pendingReload = true;
      return;
    }
    unawaited(_reload());
  }

  Future<void> _reload({bool showLoader = false}) async {
    if (!mounted || _refreshing) return;
    _refreshing = true;
    if (showLoader) {
      setState(() => _loading = true);
    }
    try {
      final entries = await LogisticsDieselConsumptionStore.loadEntries();
      var purchased = 0.0;
      var requested = 0.0;
      for (final entry in entries) {
        purchased += entry.litersPurchased;
        requested += entry.litersRequested;
      }
      final latestEntry = entries.isEmpty ? null : entries.first;
      if (!mounted) return;
      setState(() {
        _totalPurchased = purchased;
        _totalRequested = requested;
        _currentBalance = latestEntry?.balanceLiters ?? 0;
        _lastBalanceDate = latestEntry?.entryDate;
        _loading = false;
      });
    } catch (error, st) {
      AppErrorReporter.report(
        error,
        st,
        fallbackMessage: 'No se pudo cargar el resumen de diesel de Logística.',
      );
      if (!mounted) return;
      setState(() => _loading = false);
    } finally {
      _refreshing = false;
      if (_pendingReload) {
        _pendingReload = false;
        _requestReload();
      }
    }
  }

  _LogisticsDieselTankStatus get _tankStatus {
    final balance = _currentBalance;
    if (balance > 600) {
      return const _LogisticsDieselTankStatus(
        label: 'Suficiente',
        helper: 'Arriba de 600 L disponibles',
        icon: Icons.check_circle_rounded,
        topColor: Color(0xFFE5F2E6),
        bottomColor: Color(0xFFD3E9D6),
        borderColor: Color(0xFFA7CBAE),
        textColor: Color(0xFF1E6933),
      );
    }
    if (balance >= 300) {
      return const _LogisticsDieselTankStatus(
        label: 'Solicitar',
        helper: 'Entre 300 L y 600 L',
        icon: Icons.warning_amber_rounded,
        topColor: Color(0xFFF8F0D9),
        bottomColor: Color(0xFFF1E2B1),
        borderColor: Color(0xFFD8C27D),
        textColor: Color(0xFF7A6102),
      );
    }
    return const _LogisticsDieselTankStatus(
      label: 'Crítico',
      helper: 'Abajo de 300 L',
      icon: Icons.error_rounded,
      topColor: Color(0xFFF6E0DE),
      bottomColor: Color(0xFFECC6C1),
      borderColor: Color(0xFFD39D96),
      textColor: Color(0xFF892D25),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _tankStatus;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 960;
        final cards = <Widget>[
          _LogisticsDieselHeadlineCard(
            title: 'Saldo actual de diesel',
            value: _loading
                ? 'Cargando...'
                : '${_fmtDashboardLiters(_currentBalance)} L',
            helper: _loading
                ? 'Leyendo compras y solicitudes del tanque'
                : _lastBalanceDate == null
                ? 'Sin lectura vigente todavía'
                : 'Última lectura ${_dashboardFormatShortDate(_lastBalanceDate!)} · Comprados ${_fmtDashboardLiters(_totalPurchased)} L · Solicitados ${_fmtDashboardLiters(_totalRequested)} L',
            icon: Icons.local_gas_station_rounded,
            topColor: const Color(0xFFE6EBF1),
            bottomColor: const Color(0xFFD8E0E9),
            borderColor: const Color(0xFFBCC7D3),
            textColor: kLogisticsSilverTextPrimary,
            onTap: widget.onOpenSource,
          ),
          _LogisticsDieselHeadlineCard(
            title: 'Estatus del tanque',
            value: _loading ? 'Calculando...' : status.label,
            helper: _loading
                ? 'Esperando saldo real del tanque'
                : status.helper,
            icon: status.icon,
            topColor: status.topColor,
            bottomColor: status.bottomColor,
            borderColor: status.borderColor,
            textColor: status.textColor,
            onTap: widget.onOpenSource,
          ),
        ];
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [cards[0], const SizedBox(height: 12), cards[1]],
          );
        }
        return Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
          ],
        );
      },
    );
  }
}

class _LogisticsDieselTankStatus {
  final String label;
  final String helper;
  final IconData icon;
  final Color topColor;
  final Color bottomColor;
  final Color borderColor;
  final Color textColor;

  const _LogisticsDieselTankStatus({
    required this.label,
    required this.helper,
    required this.icon,
    required this.topColor,
    required this.bottomColor,
    required this.borderColor,
    required this.textColor,
  });
}

class _LogisticsDieselHeadlineCard extends StatelessWidget {
  final String title;
  final String value;
  final String helper;
  final IconData icon;
  final Color topColor;
  final Color bottomColor;
  final Color borderColor;
  final Color textColor;
  final Future<void> Function()? onTap;

  const _LogisticsDieselHeadlineCard({
    required this.title,
    required this.value,
    required this.helper,
    required this.icon,
    required this.topColor,
    required this.bottomColor,
    required this.borderColor,
    required this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final executive = _usesGerenciaExecutiveTheme(context);
    final tokens = AreaThemeScope.of(context);
    return _LogisticsDashboardWidgetShortcut(
      onTap: onTap,
      child: ContractGlassCard(
        blurSigma: 7,
        elevation: 18,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: executive
                  ? [const Color(0xFF4A1520), const Color(0xFF2A0D14)]
                  : [topColor, bottomColor],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: executive
                  ? tokens.border.withValues(alpha: 0.52)
                  : borderColor,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
              if (!executive)
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.58),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: executive
                      ? const Color(0x995D1C2A)
                      : Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: executive
                        ? tokens.border.withValues(alpha: 0.36)
                        : Colors.white.withValues(alpha: 0.88),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: executive ? tokens.primarySoft : textColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: executive
                            ? tokens.onGlass.withValues(alpha: 0.82)
                            : textColor.withValues(alpha: 0.88),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: executive ? tokens.primarySoft : textColor,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      helper,
                      style: TextStyle(
                        fontSize: 12.6,
                        fontWeight: FontWeight.w700,
                        color: executive
                            ? tokens.onGlass.withValues(alpha: 0.70)
                            : textColor.withValues(alpha: 0.82),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogisticsServicesSummaryPanel extends StatefulWidget {
  final Future<void> Function()? onOpenSource;

  const _LogisticsServicesSummaryPanel({this.onOpenSource});

  @override
  State<_LogisticsServicesSummaryPanel> createState() =>
      _LogisticsServicesSummaryPanelState();
}

class _LogisticsServicesSummaryPanelState
    extends State<_LogisticsServicesSummaryPanel>
    with WidgetsBindingObserver {
  final SupabaseClient _supa = Supabase.instance.client;
  bool _loadingDates = true;
  bool _loadingRows = true;
  bool _refreshing = false;
  bool _pendingReload = false;
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  List<DateTime> _datesWithServices = <DateTime>[];
  List<_LogisticsServiceSummaryItem> _items = <_LogisticsServiceSummaryItem>[];
  Timer? _timer;
  RealtimeChannel? _servicesRealtime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload(showLoader: true);
    _setupRealtime();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _servicesRealtime?.unsubscribe();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _requestReload();
    }
  }

  void _setupRealtime() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      _requestReload();
    });

    _servicesRealtime?.unsubscribe();
    _servicesRealtime = _supa
        .channel('logistics-dashboard-services-summary')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'services',
          callback: (_) => _requestReload(),
        )
        .subscribe();
  }

  void _requestReload() {
    if (!mounted) return;
    if (_refreshing) {
      _pendingReload = true;
      return;
    }
    unawaited(_reload());
  }

  Future<void> _reload({bool showLoader = false}) async {
    if (!mounted || _refreshing) return;
    _refreshing = true;
    try {
      await _loadDates(showLoader: showLoader);
      if (!mounted) return;
      if (_datesWithServices.isNotEmpty &&
          !_datesWithServices.contains(_selectedDate)) {
        final today = DateUtils.dateOnly(DateTime.now());
        _selectedDate = _datesWithServices.contains(today)
            ? today
            : _datesWithServices.last;
      }
      await _loadRowsForSelectedDate(showLoader: showLoader);
    } finally {
      _refreshing = false;
      if (_pendingReload) {
        _pendingReload = false;
        _requestReload();
      }
    }
  }

  Future<void> _loadDates({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => _loadingDates = true);
    }
    try {
      final data = await _supa
          .from('services')
          .select('due_date')
          .not('due_date', 'is', null)
          .order('due_date');
      final set = <DateTime>{};
      for (final row in (data as List)) {
        final value = (row as Map<String, dynamic>)['due_date'];
        if (value == null) continue;
        set.add(DateUtils.dateOnly(_dashboardParseDate(value)));
      }
      final sorted = set.toList()..sort();
      if (!mounted) return;
      setState(() {
        _datesWithServices = sorted;
        if (showLoader) _loadingDates = false;
      });
    } catch (error, st) {
      AppErrorReporter.report(
        error,
        st,
        fallbackMessage:
            'No se pudieron cargar las fechas del resumen de servicios.',
      );
      if (!mounted) return;
      setState(() {
        _datesWithServices = const <DateTime>[];
        if (showLoader) _loadingDates = false;
      });
    }
  }

  Future<void> _loadRowsForSelectedDate({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => _loadingRows = true);
    }
    try {
      final data = await _supa
          .from('v_services_grid')
          .select('*')
          .eq('due_date', _dashboardFmtDbDate(_selectedDate))
          .order('created_at');
      final rows = (data as List).cast<Map<String, dynamic>>();
      final mapped = rows
          .map((row) {
            final company =
                ((row['client_name'] ?? row['client_label'] ?? 'SIN EMPRESA')
                        as String)
                    .trim();
            final operator = ((row['driver_name'] ?? 'SIN OPERADOR') as String)
                .trim();
            final status = _dashboardFormatStatus(
              ((row['status'] ?? '') as String).trim(),
            );
            return _LogisticsServiceSummaryItem(
              company: company.isEmpty ? 'SIN EMPRESA' : company,
              operator: operator.isEmpty ? 'SIN OPERADOR' : operator,
              status: status.isEmpty ? 'Sin estado' : status,
            );
          })
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _items = mapped;
        if (showLoader) _loadingRows = false;
      });
    } catch (error, st) {
      AppErrorReporter.report(
        error,
        st,
        fallbackMessage:
            'No se pudo cargar el resumen de viajes y servicios de Logística.',
      );
      if (!mounted) return;
      setState(() {
        _items = const <_LogisticsServiceSummaryItem>[];
        if (showLoader) _loadingRows = false;
      });
    }
  }

  DateTime? get _prevDate {
    final prev =
        _datesWithServices.where((d) => d.isBefore(_selectedDate)).toList()
          ..sort();
    return prev.isEmpty ? null : prev.last;
  }

  DateTime? get _nextDate {
    final next =
        _datesWithServices.where((d) => d.isAfter(_selectedDate)).toList()
          ..sort();
    return next.isEmpty ? null : next.first;
  }

  Future<void> _goToDate(DateTime date) async {
    setState(() => _selectedDate = DateUtils.dateOnly(date));
    await _loadRowsForSelectedDate(showLoader: true);
  }

  @override
  Widget build(BuildContext context) {
    final loading = (_loadingDates || _loadingRows) && _items.isEmpty;
    final tokens = AreaThemeScope.of(context);
    final executive = _usesGerenciaExecutiveTheme(context);
    return _LogisticsDashboardWidgetShortcut(
      onTap: widget.onOpenSource,
      child: ContractGlassCard(
        blurSigma: 7,
        elevation: 20,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: _logisticsExecutiveModuleGradient(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _logisticsExecutiveBorder(context, alpha: 0.82),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
              if (!executive)
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.54),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            children: [
              Row(
                children: [
                  _LogisticsMiniNavButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    enabled: _prevDate != null,
                    onTap: _prevDate == null
                        ? null
                        : () => _goToDate(_prevDate!),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Resumen de Viajes y Servicios',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: tokens.onGlass,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dashboardFormatLongDateEs(_selectedDate),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: _logisticsExecutiveMutedText(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_items.length} servicio${_items.length == 1 ? '' : 's'}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _logisticsExecutiveMutedText(
                              context,
                              alpha: 0.62,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _LogisticsMiniNavButton(
                    icon: Icons.arrow_forward_ios_rounded,
                    enabled: _nextDate != null,
                    onTap: _nextDate == null
                        ? null
                        : () => _goToDate(_nextDate!),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: _logisticsExecutiveCapsuleGradient(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _logisticsExecutiveBorder(context)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'EMPRESA',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: tokens.onGlass,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'OPERADOR',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: tokens.onGlass,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'ESTADO',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: tokens.onGlass,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : _items.isEmpty
                    ? Center(
                        child: Text(
                          'No hay servicios para la fecha seleccionada.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _logisticsExecutiveMutedText(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : ListView.separated(
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: executive
                                  ? const Color(0x522A0D14)
                                  : Colors.white.withValues(alpha: 0.74),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: executive
                                    ? tokens.border.withValues(alpha: 0.36)
                                    : kLogisticsSilverBorderLight.withValues(
                                        alpha: 0.86,
                                      ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    item.company,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.4,
                                      fontWeight: FontWeight.w800,
                                      color: tokens.onGlass,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    item.operator,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.2,
                                      fontWeight: FontWeight.w700,
                                      color: _logisticsExecutiveMutedText(
                                        context,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: _LogisticsStateChip(
                                      text: item.status,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogisticsWeeklyDriverCharts extends StatefulWidget {
  final double width;
  final bool preferSideBySide;
  final double chartHeight;
  final Future<void> Function()? onOpenDieselSource;
  final Future<void> Function()? onOpenGasolineSource;
  final Future<void> Function()? onOpenServicesSource;

  const _LogisticsWeeklyDriverCharts({
    required this.width,
    this.preferSideBySide = false,
    this.chartHeight = 350,
    this.onOpenDieselSource,
    this.onOpenGasolineSource,
    this.onOpenServicesSource,
  });

  @override
  State<_LogisticsWeeklyDriverCharts> createState() =>
      _LogisticsWeeklyDriverChartsState();
}

class _LogisticsWeeklyDriverChartsState
    extends State<_LogisticsWeeklyDriverCharts>
    with WidgetsBindingObserver {
  final SupabaseClient _supa = Supabase.instance.client;
  bool _loadingMeta = true;
  bool _loadingWeek = true;
  bool _refreshing = false;
  bool _pendingReload = false;
  List<DateTime> _availableWeeks = <DateTime>[];
  DateTime _selectedWeekStart = _dashboardWeekStart(DateTime.now());
  List<_LogisticsDriverMetricRow> _litersRows = <_LogisticsDriverMetricRow>[];
  List<_LogisticsDriverMetricRow> _gasolineRows = <_LogisticsDriverMetricRow>[];
  List<_LogisticsDriverMetricRow> _tripRows = <_LogisticsDriverMetricRow>[];
  Timer? _timer;
  RealtimeChannel? _dieselRealtime;
  RealtimeChannel? _gasolineRealtime;
  RealtimeChannel? _servicesRealtime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload(showLoader: true);
    _setupRealtime();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _dieselRealtime?.unsubscribe();
    _gasolineRealtime?.unsubscribe();
    _servicesRealtime?.unsubscribe();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _requestReload();
    }
  }

  void _setupRealtime() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 18), (_) {
      _requestReload();
    });

    _dieselRealtime?.unsubscribe();
    _dieselRealtime = _supa
        .channel('logistics-dashboard-weekly-diesel')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'logistics_diesel_consumption',
          callback: (_) => _requestReload(),
        )
        .subscribe();

    _gasolineRealtime?.unsubscribe();
    _gasolineRealtime = _supa
        .channel('logistics-dashboard-weekly-gasoline')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'logistics_gasoline_control',
          callback: (_) => _requestReload(),
        )
        .subscribe();

    _servicesRealtime?.unsubscribe();
    _servicesRealtime = _supa
        .channel('logistics-dashboard-weekly-services')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'services',
          callback: (_) => _requestReload(),
        )
        .subscribe();
  }

  void _requestReload() {
    if (!mounted) return;
    if (_refreshing) {
      _pendingReload = true;
      return;
    }
    unawaited(_reload());
  }

  Future<void> _reload({bool showLoader = false}) async {
    if (!mounted || _refreshing) return;
    _refreshing = true;
    try {
      await _loadAvailableWeeks(showLoader: showLoader);
      if (!mounted) return;
      if (_availableWeeks.isNotEmpty &&
          !_availableWeeks.contains(_selectedWeekStart)) {
        final currentWeek = _dashboardWeekStart(DateTime.now());
        _selectedWeekStart = _availableWeeks.contains(currentWeek)
            ? currentWeek
            : _availableWeeks.last;
      }
      await _loadWeekMetrics(showLoader: showLoader);
    } finally {
      _refreshing = false;
      if (_pendingReload) {
        _pendingReload = false;
        _requestReload();
      }
    }
  }

  Future<void> _loadAvailableWeeks({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => _loadingMeta = true);
    }
    try {
      final results = await Future.wait<dynamic>([
        _supa
            .from('services')
            .select('due_date')
            .not('due_date', 'is', null)
            .order('due_date'),
        _supa
            .from('logistics_diesel_consumption')
            .select('entry_date')
            .not('entry_date', 'is', null)
            .order('entry_date'),
        _supa
            .from('logistics_gasoline_control')
            .select('entry_date')
            .not('entry_date', 'is', null)
            .order('entry_date'),
      ]);
      final weeks = <DateTime>{};
      for (final row in (results[0] as List)) {
        final value = (row as Map<String, dynamic>)['due_date'];
        if (value == null) continue;
        weeks.add(_dashboardWeekStart(_dashboardParseDate(value)));
      }
      for (final row in (results[1] as List)) {
        final value = (row as Map<String, dynamic>)['entry_date'];
        if (value == null) continue;
        weeks.add(_dashboardWeekStart(_dashboardParseDate(value)));
      }
      for (final row in (results[2] as List)) {
        final value = (row as Map<String, dynamic>)['entry_date'];
        if (value == null) continue;
        weeks.add(_dashboardWeekStart(_dashboardParseDate(value)));
      }
      final sorted = weeks.toList()..sort();
      if (!mounted) return;
      setState(() {
        _availableWeeks = sorted;
        if (showLoader) _loadingMeta = false;
      });
    } catch (error, st) {
      AppErrorReporter.report(
        error,
        st,
        fallbackMessage:
            'No se pudieron cargar las semanas disponibles del dashboard de Logística.',
      );
      if (!mounted) return;
      setState(() {
        _availableWeeks = const <DateTime>[];
        if (showLoader) _loadingMeta = false;
      });
    }
  }

  Future<void> _loadWeekMetrics({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => _loadingWeek = true);
    }
    final weekEnd = _selectedWeekStart.add(const Duration(days: 6));
    try {
      final results = await Future.wait<dynamic>([
        _supa
            .from('logistics_diesel_consumption')
            .select('operator_name,liters_requested')
            .gte('entry_date', _dashboardFmtDbDate(_selectedWeekStart))
            .lte('entry_date', _dashboardFmtDbDate(weekEnd))
            .order('operator_name'),
        _supa
            .from('logistics_gasoline_control')
            .select('operator_name,liters_loaded')
            .gte('entry_date', _dashboardFmtDbDate(_selectedWeekStart))
            .lte('entry_date', _dashboardFmtDbDate(weekEnd))
            .order('operator_name'),
        _supa
            .from('services')
            .select('driver_employee_id,due_date')
            .gte('due_date', _dashboardFmtDbDate(_selectedWeekStart))
            .lte('due_date', _dashboardFmtDbDate(weekEnd))
            .order('due_date'),
        _supa
            .from('employees')
            .select('id,full_name')
            .eq('is_driver', true)
            .order('full_name'),
      ]);

      final litersByDriver = <String, double>{};
      for (final row in (results[0] as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        final driver = _dashboardNormalizedLabel(
          (map['operator_name'] ?? '').toString(),
          fallback: 'Sin operador',
        );
        final liters = _dashboardTryParseDouble(map['liters_requested']) ?? 0;
        litersByDriver[driver] = (litersByDriver[driver] ?? 0) + liters;
      }

      final gasolineByDriver = <String, double>{};
      for (final row in (results[1] as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        final driver = _dashboardNormalizedLabel(
          (map['operator_name'] ?? '').toString(),
          fallback: 'Sin operador',
        );
        final liters = _dashboardTryParseDouble(map['liters_loaded']) ?? 0;
        gasolineByDriver[driver] = (gasolineByDriver[driver] ?? 0) + liters;
      }

      final driverNamesById = <String, String>{};
      for (final row in (results[3] as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        final id = (map['id'] ?? '').toString().trim();
        final label = (map['full_name'] ?? '').toString().trim();
        if (id.isEmpty || label.isEmpty) continue;
        driverNamesById[id] = label;
      }

      final tripsByDriver = <String, double>{};
      for (final row in (results[2] as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        final driver = _dashboardNormalizedLabel(
          driverNamesById[(map['driver_employee_id'] ?? '')
                  .toString()
                  .trim()] ??
              '',
          fallback: 'Sin chofer',
        );
        tripsByDriver[driver] = (tripsByDriver[driver] ?? 0) + 1;
      }

      final litersRows =
          litersByDriver.entries
              .map(
                (entry) => _LogisticsDriverMetricRow(
                  label: entry.key,
                  value: entry.value,
                ),
              )
              .toList(growable: false)
            ..sort((a, b) {
              final cmp = b.value.compareTo(a.value);
              if (cmp != 0) return cmp;
              return a.label.compareTo(b.label);
            });

      final gasolineRows =
          gasolineByDriver.entries
              .map(
                (entry) => _LogisticsDriverMetricRow(
                  label: entry.key,
                  value: entry.value,
                ),
              )
              .toList(growable: false)
            ..sort((a, b) {
              final cmp = b.value.compareTo(a.value);
              if (cmp != 0) return cmp;
              return a.label.compareTo(b.label);
            });

      final tripRows =
          tripsByDriver.entries
              .map(
                (entry) => _LogisticsDriverMetricRow(
                  label: entry.key,
                  value: entry.value,
                ),
              )
              .toList(growable: false)
            ..sort((a, b) {
              final cmp = b.value.compareTo(a.value);
              if (cmp != 0) return cmp;
              return a.label.compareTo(b.label);
            });

      if (!mounted) return;
      setState(() {
        _litersRows = litersRows;
        _gasolineRows = gasolineRows;
        _tripRows = tripRows;
        if (showLoader) _loadingWeek = false;
      });
    } catch (error, st) {
      AppErrorReporter.report(
        error,
        st,
        fallbackMessage:
            'No se pudieron cargar las gráficas semanales de Logística.',
      );
      if (!mounted) return;
      setState(() {
        _litersRows = const <_LogisticsDriverMetricRow>[];
        _gasolineRows = const <_LogisticsDriverMetricRow>[];
        _tripRows = const <_LogisticsDriverMetricRow>[];
        if (showLoader) _loadingWeek = false;
      });
    }
  }

  DateTime? get _prevWeek {
    final index = _availableWeeks.indexOf(_selectedWeekStart);
    if (index <= 0) return null;
    return _availableWeeks[index - 1];
  }

  DateTime? get _nextWeek {
    final index = _availableWeeks.indexOf(_selectedWeekStart);
    if (index < 0 || index >= _availableWeeks.length - 1) return null;
    return _availableWeeks[index + 1];
  }

  Future<void> _goToWeek(DateTime weekStart) async {
    setState(() => _selectedWeekStart = weekStart);
    await _loadWeekMetrics(showLoader: true);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final executive = tokens.darkGlass;
    final stacked = widget.preferSideBySide
        ? widget.width < 760
        : widget.width < 1240;
    final loading = _loadingMeta || _loadingWeek;
    final weekLabel = _dashboardFormatWeekRangeEs(_selectedWeekStart);
    final weekSubtitle = _availableWeeks.isEmpty
        ? 'Sin semanas con datos todavía'
        : 'Navega entre semanas reales de diesel, gasolina y viajes';

    final charts = <Widget>[
      SizedBox(
        height: widget.chartHeight,
        child: _LogisticsDriverLeaderboardCard(
          title: 'Control de Diesel',
          subtitle: 'Litros solicitados por chofer en la semana',
          loading: loading,
          rows: _litersRows,
          emptyMessage: 'Todavía no hay litros solicitados en esta semana.',
          valueFormatter: (value) => '${_fmtDashboardLiters(value)} L',
          totalLabel: 'Litros solicitados',
          averageLabel: 'Promedio por chofer',
          columnLabel: 'Litros solicitados',
          footerNote: 'Ordenado de mayor a menor por litros solicitados.',
          primaryIcon: Icons.local_gas_station_rounded,
          secondaryIcon: Icons.timeline_rounded,
          primaryAccent: executive
              ? const Color(0xFFFF9FA7)
              : const Color(0xFF526C8A),
          secondaryAccent: executive
              ? const Color(0xFFFFC7CF)
              : const Color(0xFF7B8795),
          barTopColor: executive
              ? const Color(0xFFFF8A7A)
              : const Color(0xFFAFBAC7),
          barBottomColor: executive
              ? const Color(0xFFB23346)
              : const Color(0xFF7B8795),
          onOpenSource: widget.onOpenDieselSource,
        ),
      ),
      SizedBox(
        height: widget.chartHeight,
        child: _LogisticsDriverLeaderboardCard(
          title: 'Control de Gasolina',
          subtitle: 'Litros cargados por chofer en la semana',
          loading: loading,
          rows: _gasolineRows,
          emptyMessage: 'Todavía no hay cargas de gasolina en esta semana.',
          valueFormatter: (value) => '${_fmtDashboardLiters(value)} L',
          totalLabel: 'Litros cargados',
          averageLabel: 'Promedio por chofer',
          columnLabel: 'Litros cargados',
          footerNote: 'Ordenado de mayor a menor por litros cargados.',
          primaryIcon: Icons.local_gas_station_outlined,
          secondaryIcon: Icons.route_rounded,
          primaryAccent: executive
              ? const Color(0xFFFFC07A)
              : const Color(0xFF6B727A),
          secondaryAccent: executive
              ? const Color(0xFFFFE0AB)
              : const Color(0xFF868D96),
          barTopColor: executive
              ? const Color(0xFFFFB35C)
              : const Color(0xFFC2C7CC),
          barBottomColor: executive
              ? const Color(0xFFC46A35)
              : const Color(0xFF7A838D),
          onOpenSource: widget.onOpenGasolineSource,
        ),
      ),
      SizedBox(
        height: widget.chartHeight,
        child: _LogisticsDriverLeaderboardCard(
          title: 'Número de viajes',
          subtitle: 'Viajes asignados por chofer en la semana',
          loading: loading,
          rows: _tripRows,
          emptyMessage: 'Todavía no hay viajes asignados en esta semana.',
          valueFormatter: (value) => _fmtDashboardCount(value),
          totalLabel: 'Viajes asignados',
          averageLabel: 'Promedio por chofer',
          columnLabel: 'Viajes asignados',
          footerNote: 'Ordenado de mayor a menor por número de viajes.',
          primaryIcon: Icons.work_outline_rounded,
          secondaryIcon: Icons.analytics_outlined,
          primaryAccent: executive
              ? const Color(0xFFFF9FA7)
              : const Color(0xFF5A78B0),
          secondaryAccent: executive
              ? const Color(0xFFFFC7CF)
              : const Color(0xFF7F96C4),
          barTopColor: executive
              ? const Color(0xFFE46A78)
              : const Color(0xFF8FA4B8),
          barBottomColor: executive
              ? const Color(0xFF8F2737)
              : const Color(0xFF546272),
          onOpenSource: widget.onOpenServicesSource,
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ContractGlassCard(
          blurSigma: 7,
          elevation: 18,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Container(
            decoration: BoxDecoration(
              gradient: _logisticsExecutiveCapsuleGradient(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _logisticsExecutiveBorder(context)),
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                _LogisticsMiniNavButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  enabled: _prevWeek != null,
                  onTap: _prevWeek == null ? null : () => _goToWeek(_prevWeek!),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Semana operativa por chofer',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: tokens.onGlass,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        weekLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: _logisticsExecutiveMutedText(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        weekSubtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.8,
                          fontWeight: FontWeight.w700,
                          color: _logisticsExecutiveMutedText(
                            context,
                            alpha: 0.62,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _LogisticsMiniNavButton(
                  icon: Icons.arrow_forward_ios_rounded,
                  enabled: _nextWeek != null,
                  onTap: _nextWeek == null ? null : () => _goToWeek(_nextWeek!),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final fullWidth = constraints.maxWidth;
            if (!stacked && fullWidth >= 1480) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: charts[0]),
                  const SizedBox(width: 12),
                  Expanded(child: charts[1]),
                  const SizedBox(width: 12),
                  Expanded(child: charts[2]),
                ],
              );
            }
            if (!stacked && fullWidth >= 980) {
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: charts[0]),
                      const SizedBox(width: 12),
                      Expanded(child: charts[1]),
                    ],
                  ),
                  const SizedBox(height: 12),
                  charts[2],
                ],
              );
            }
            return Column(
              children: [
                charts[0],
                const SizedBox(height: 12),
                charts[1],
                const SizedBox(height: 12),
                charts[2],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LogisticsDriverLeaderboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool loading;
  final List<_LogisticsDriverMetricRow> rows;
  final String emptyMessage;
  final String Function(double value) valueFormatter;
  final String totalLabel;
  final String averageLabel;
  final String columnLabel;
  final String footerNote;
  final IconData primaryIcon;
  final IconData secondaryIcon;
  final Color primaryAccent;
  final Color secondaryAccent;
  final Color barTopColor;
  final Color barBottomColor;
  final Future<void> Function()? onOpenSource;

  const _LogisticsDriverLeaderboardCard({
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.rows,
    required this.emptyMessage,
    required this.valueFormatter,
    required this.totalLabel,
    required this.averageLabel,
    required this.columnLabel,
    required this.footerNote,
    required this.primaryIcon,
    required this.secondaryIcon,
    required this.primaryAccent,
    required this.secondaryAccent,
    required this.barTopColor,
    required this.barBottomColor,
    this.onOpenSource,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final totalValue = rows.fold<double>(0, (sum, row) => sum + row.value);
    final averageValue = rows.isEmpty ? 0.0 : totalValue / rows.length;
    return _LogisticsDashboardWidgetShortcut(
      onTap: onOpenSource,
      child: ContractGlassCard(
        blurSigma: 7,
        elevation: 18,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Container(
          decoration: BoxDecoration(
            gradient: _logisticsExecutiveModuleGradient(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _logisticsExecutiveBorder(context, alpha: 0.80),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: tokens.onGlass,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12.8,
                  fontWeight: FontWeight.w700,
                  color: tokens.onGlass.withValues(alpha: 0.78),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 420;
                  final cards = [
                    _LogisticsDriverMetricSummaryCard(
                      icon: primaryIcon,
                      accent: primaryAccent,
                      value: valueFormatter(totalValue),
                      label: totalLabel,
                    ),
                    _LogisticsDriverMetricSummaryCard(
                      icon: secondaryIcon,
                      accent: secondaryAccent,
                      value: valueFormatter(averageValue),
                      label: averageLabel,
                    ),
                  ];
                  if (stacked) {
                    return Column(
                      children: [
                        cards[0],
                        const SizedBox(height: 10),
                        cards[1],
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 10),
                      Expanded(child: cards[1]),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: _logisticsExecutiveCapsuleGradient(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _logisticsExecutiveBorder(context)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        'Chofer',
                        style: TextStyle(
                          fontSize: 11.8,
                          fontWeight: FontWeight.w900,
                          color: tokens.onGlass.withValues(alpha: 0.82),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 6,
                      child: Text(
                        columnLabel,
                        style: TextStyle(
                          fontSize: 11.8,
                          fontWeight: FontWeight.w900,
                          color: primaryAccent,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 82,
                      child: Text(
                        '% del total',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11.8,
                          fontWeight: FontWeight.w900,
                          color: tokens.onGlass.withValues(alpha: 0.82),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : rows.isEmpty
                    ? Center(
                        child: Text(
                          emptyMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _logisticsExecutiveMutedText(context),
                          ),
                        ),
                      )
                    : ListView.separated(
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          return _LogisticsDriverLeaderboardRow(
                            row: row,
                            totalValue: totalValue,
                            averageValue: averageValue,
                            maxValue: _dashboardMaxMetricValue(rows),
                            valueFormatter: valueFormatter,
                            barTopColor: barTopColor,
                            barBottomColor: barBottomColor,
                            accentColor: primaryAccent,
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: tokens.onGlass.withValues(alpha: 0.66),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      footerNote,
                      style: TextStyle(
                        fontSize: 11.8,
                        fontWeight: FontWeight.w700,
                        color: tokens.onGlass.withValues(alpha: 0.66),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogisticsDriverMetricSummaryCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String value;
  final String label;

  const _LogisticsDriverMetricSummaryCard({
    required this.icon,
    required this.accent,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final executive = _usesGerenciaExecutiveTheme(context);
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: executive
            ? const Color(0x522A0D14)
            : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: executive
              ? tokens.border.withValues(alpha: 0.34)
              : kLogisticsSilverBorderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: accent,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.4,
                    fontWeight: FontWeight.w700,
                    color: _logisticsExecutiveMutedText(context),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogisticsDriverLeaderboardRow extends StatelessWidget {
  final _LogisticsDriverMetricRow row;
  final double totalValue;
  final double averageValue;
  final double maxValue;
  final String Function(double value) valueFormatter;
  final Color barTopColor;
  final Color barBottomColor;
  final Color accentColor;

  const _LogisticsDriverLeaderboardRow({
    required this.row,
    required this.totalValue,
    required this.averageValue,
    required this.maxValue,
    required this.valueFormatter,
    required this.barTopColor,
    required this.barBottomColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final executive = _usesGerenciaExecutiveTheme(context);
    final tokens = AreaThemeScope.of(context);
    final ratio = maxValue <= 0 ? 0.0 : (row.value / maxValue).clamp(0.0, 1.0);
    final averageRatio = maxValue <= 0
        ? 0.0
        : (averageValue / maxValue).clamp(0.0, 1.0);
    final percent = totalValue <= 0 ? 0.0 : (row.value / totalValue) * 100;
    final tooltipMessage = '${row.label}\n${valueFormatter(row.value)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: executive
            ? const Color(0x452A0D14)
            : Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: executive
              ? tokens.border.withValues(alpha: 0.32)
              : kLogisticsSilverBorderLight.withValues(alpha: 0.88),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accentColor.withValues(alpha: 0.16),
                        accentColor.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _dashboardInitials(row.label),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    row.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.8,
                      fontWeight: FontWeight.w800,
                      color: tokens.onGlass,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Row(
              children: [
                Expanded(
                  child: Tooltip(
                    message: tooltipMessage,
                    waitDuration: const Duration(milliseconds: 180),
                    showDuration: const Duration(seconds: 3),
                    preferBelow: false,
                    verticalOffset: 18,
                    textStyle: const TextStyle(
                      color: kLogisticsSilverTextPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                    decoration: BoxDecoration(
                      gradient: kLogisticsCapsuleGradient,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: kLogisticsSilverBorder.withValues(alpha: 0.92),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final markerLeft = averageRatio * width;
                        return Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                              height: 26,
                              decoration: BoxDecoration(
                                color: executive
                                    ? const Color(0x664A1520)
                                    : const Color(0xFFEFF2F6),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            if (averageRatio > 0)
                              Positioned(
                                left: math.max(
                                  0,
                                  math.min(width - 2, markerLeft),
                                ),
                                top: 1,
                                bottom: 1,
                                child: Container(
                                  width: 2,
                                  decoration: BoxDecoration(
                                    color: _logisticsExecutiveMutedText(
                                      context,
                                      alpha: 0.40,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            FractionallySizedBox(
                              widthFactor: ratio,
                              child: Container(
                                height: 26,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [barTopColor, barBottomColor],
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: [
                                    BoxShadow(
                                      color: barBottomColor.withValues(
                                        alpha: 0.24,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 7),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 54,
                  child: Text(
                    valueFormatter(row.value),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.8,
                      fontWeight: FontWeight.w900,
                      color: tokens.onGlass,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 82,
            child: Text(
              _fmtDashboardPercent(percent),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.8,
                fontWeight: FontWeight.w900,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogisticsDashboardWidgetShortcut extends StatefulWidget {
  final Widget child;
  final Future<void> Function()? onTap;

  const _LogisticsDashboardWidgetShortcut({required this.child, this.onTap});

  @override
  State<_LogisticsDashboardWidgetShortcut> createState() =>
      _LogisticsDashboardWidgetShortcutState();
}

class _LogisticsDashboardWidgetShortcutState
    extends State<_LogisticsDashboardWidgetShortcut> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) {
      return widget.child;
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        scale: _hovered ? 1.02 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
          child: GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onTap: () async => widget.onTap!(),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _LogisticsMiniNavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _LogisticsMiniNavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final executive = tokens.darkGlass;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: enabled
              ? _logisticsExecutiveCapsuleGradient(context)
              : null,
          color: enabled
              ? null
              : executive
              ? const Color(0x334A1520)
              : Colors.white.withValues(alpha: 0.36),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled
                ? _logisticsExecutiveBorder(context)
                : _logisticsExecutiveBorder(context, alpha: 0.54),
          ),
        ),
        child: Icon(
          icon,
          size: 17,
          color: enabled
              ? tokens.onGlass
              : _logisticsExecutiveMutedText(context, alpha: 0.52),
        ),
      ),
    );
  }
}

class _LogisticsStateChip extends StatelessWidget {
  final String text;

  const _LogisticsStateChip({required this.text});

  Color _backgroundFor(String value) {
    final key = value.toLowerCase().replaceAll(' ', '_');
    if (key.contains('cancelado')) return const Color(0xFFF8DAD8);
    if (key.contains('completado')) return const Color(0xFFD9E8FF);
    if (key.contains('en_ruta')) return const Color(0xFFD8FBF3);
    if (key.contains('confirmado')) return const Color(0xFFE1F9E9);
    return const Color(0xFFEAF1F1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _backgroundFor(text),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: kLogisticsSilverTextPrimary,
        ),
      ),
    );
  }
}

class _LogisticsServiceSummaryItem {
  final String company;
  final String operator;
  final String status;

  const _LogisticsServiceSummaryItem({
    required this.company,
    required this.operator,
    required this.status,
  });
}

class _LogisticsDriverMetricRow {
  final String label;
  final double value;

  const _LogisticsDriverMetricRow({required this.label, required this.value});
}

DateTime _dashboardParseDate(dynamic raw) {
  final value = raw?.toString().trim() ?? '';
  if (value.length >= 10) {
    final year = int.tryParse(value.substring(0, 4));
    final month = int.tryParse(value.substring(5, 7));
    final day = int.tryParse(value.substring(8, 10));
    if (year != null && month != null && day != null) {
      return DateTime(year, month, day);
    }
  }
  return DateUtils.dateOnly(DateTime.now());
}

String _dashboardFmtDbDate(DateTime value) {
  final mm = value.month.toString().padLeft(2, '0');
  final dd = value.day.toString().padLeft(2, '0');
  return '${value.year}-$mm-$dd';
}

String _dashboardFormatStatus(String statusRaw) {
  return statusRaw
      .replaceAll('_', ' ')
      .split(' ')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String _dashboardFormatLongDateEs(DateTime value) {
  const weekdays = <String>[
    'lunes',
    'martes',
    'miercoles',
    'jueves',
    'viernes',
    'sabado',
    'domingo',
  ];
  const months = <String>[
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  return '${weekdays[value.weekday - 1]} ${value.day} de ${months[value.month - 1]} de ${value.year}';
}

String _dashboardFormatShortDate(DateTime value) {
  final dd = value.day.toString().padLeft(2, '0');
  final mm = value.month.toString().padLeft(2, '0');
  final yy = (value.year % 100).toString().padLeft(2, '0');
  return '$dd/$mm/$yy';
}

DateTime _dashboardWeekStart(DateTime value) {
  final day = DateUtils.dateOnly(value);
  return day.subtract(Duration(days: day.weekday - 1));
}

String _dashboardFormatWeekRangeEs(DateTime weekStart) {
  final weekEnd = weekStart.add(const Duration(days: 6));
  const months = <String>[
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  final startMonth = months[weekStart.month - 1];
  final endMonth = months[weekEnd.month - 1];
  if (weekStart.month == weekEnd.month && weekStart.year == weekEnd.year) {
    return 'Semana del ${weekStart.day} al ${weekEnd.day} de $startMonth de ${weekStart.year}';
  }
  return 'Semana del ${weekStart.day} de $startMonth al ${weekEnd.day} de $endMonth de ${weekEnd.year}';
}

String _dashboardNormalizedLabel(String raw, {required String fallback}) {
  final value = raw.trim();
  return value.isEmpty ? fallback : value;
}

double? _dashboardTryParseDouble(dynamic raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw.trim());
  return null;
}

double _dashboardMaxMetricValue(List<_LogisticsDriverMetricRow> rows) {
  var maxValue = 0.0;
  for (final row in rows) {
    if (row.value > maxValue) maxValue = row.value;
  }
  return maxValue;
}

String _fmtDashboardLiters(double value) {
  if (value == value.truncateToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

String _fmtDashboardCount(double value) {
  final normalized = value.round();
  return normalized.toString();
}

String _fmtDashboardPercent(double value) {
  if (value.isNaN || value.isInfinite) return '0.0%';
  return '${value.toStringAsFixed(1)}%';
}

String _dashboardInitials(String raw) {
  final words = raw
      .trim()
      .split(RegExp(r'\s+'))
      .where((element) => element.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return '—';
  if (words.length == 1) {
    final single = words.first.toUpperCase();
    return single.length >= 2 ? single.substring(0, 2) : single;
  }
  final first = words.first.isEmpty ? '' : words.first[0];
  final second = words[1].isEmpty ? '' : words[1][0];
  return '$first$second'.toUpperCase();
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
                      gradient: _logisticsExecutiveModuleGradient(context),
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
                        if (!_usesGerenciaExecutiveTheme(context))
                          BoxShadow(
                            color: Colors.white.withValues(
                              alpha: _hovered ? 0.64 : 0.48,
                            ),
                            blurRadius: _hovered ? 14 : 10,
                            offset: const Offset(0, -2),
                          ),
                        BoxShadow(
                          color:
                              (_usesGerenciaExecutiveTheme(context)
                                      ? tokens.glow
                                      : kLogisticsSilverGlowEdge)
                                  .withValues(alpha: _hovered ? 0.42 : 0.26),
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
                                gradient: _usesGerenciaExecutiveTheme(context)
                                    ? const LinearGradient(
                                        colors: [
                                          Color(0xFFB23346),
                                          Color(0xFF4A1520),
                                        ],
                                      )
                                    : kLogisticsHeroIconGradient,
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
                                    color:
                                        (_usesGerenciaExecutiveTheme(context)
                                                ? tokens.glow
                                                : kLogisticsSilverGlow)
                                            .withValues(alpha: 0.34),
                                    blurRadius: 14,
                                  ),
                                ],
                              ),
                              child: Icon(
                                widget.icon,
                                color: _usesGerenciaExecutiveTheme(context)
                                    ? tokens.primarySoft
                                    : kLogisticsSilverIcon,
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
                                      gradient:
                                          _logisticsExecutiveCapsuleGradient(
                                            context,
                                          ),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: _logisticsExecutiveBorder(
                                          context,
                                        ),
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
                                          color:
                                              (_usesGerenciaExecutiveTheme(
                                                        context,
                                                      )
                                                      ? tokens.glow
                                                      : kLogisticsSilverGlow)
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
                                        color: _logisticsExecutiveMutedText(
                                          context,
                                          alpha: 0.9,
                                        ),
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
                            gradient: _logisticsExecutiveCapsuleGradient(
                              context,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: _logisticsExecutiveBorder(context),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 6),
                              ),
                              BoxShadow(
                                color:
                                    (_usesGerenciaExecutiveTheme(context)
                                            ? tokens.glow
                                            : kLogisticsSilverGlow)
                                        .withValues(alpha: 0.24),
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
                                color: _logisticsExecutiveMutedText(context),
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: _usesGerenciaExecutiveTheme(context)
                                  ? tokens.primarySoft
                                  : kLogisticsSilverIcon,
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
