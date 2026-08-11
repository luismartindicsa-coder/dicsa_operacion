import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final Future<void> Function() onOpenDiesel;
  final Future<void> Function() onOpenIncidents;
  final Future<void> Function() onOpenSavings;

  const _LogisticsDashboardWorkspace({
    required this.width,
    required this.onOpenControlDiario,
    required this.onOpenUnits,
    required this.onOpenCatalogs,
    required this.onOpenDiesel,
    required this.onOpenIncidents,
    required this.onOpenSavings,
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
              final shareRow = availableWidth >= 1360;
              final summaryHeight = shareRow
                  ? 412.0
                  : availableWidth < 1080
                  ? 430.0
                  : 390.0;
              final weeklyWidth = shareRow
                  ? ((availableWidth - 14) * 0.60)
                  : availableWidth;
              final summaryPanel = SizedBox(
                height: summaryHeight,
                child: _LogisticsServicesSummaryPanel(
                  onOpenSource: onOpenControlDiario,
                ),
              );
              final weeklyPanel = _LogisticsWeeklyDriverCharts(
                width: weeklyWidth,
                preferSideBySide: shareRow,
                chartHeight: shareRow ? 320 : 350,
                onOpenDieselSource: onOpenDiesel,
                onOpenServicesSource: onOpenControlDiario,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LogisticsDieselStatusStrip(onOpenSource: onOpenDiesel),
                  const SizedBox(height: 14),
                  if (shareRow)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 4, child: summaryPanel),
                        const SizedBox(width: 14),
                        Expanded(flex: 6, child: weeklyPanel),
                      ],
                    )
                  else ...[
                    summaryPanel,
                    const SizedBox(height: 14),
                    weeklyPanel,
                  ],
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.48),
            const Color(0xFFF2F4F7).withValues(alpha: 0.76),
            const Color(0xFFD8DDE3).withValues(alpha: 0.62),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: kLogisticsSilverBorder.withValues(alpha: 0.56),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
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
  double _totalBalance = 0;
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
      var balance = 0.0;
      for (final entry in entries) {
        purchased += entry.litersPurchased;
        requested += entry.litersRequested;
        balance += entry.balanceLiters;
      }
      if (!mounted) return;
      setState(() {
        _totalPurchased = purchased;
        _totalRequested = requested;
        _totalBalance = balance;
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
    final balance = _totalBalance;
    if (balance > 600) {
      return const _LogisticsDieselTankStatus(
        label: 'Suficiente',
        helper: 'Arriba de 600 L disponibles',
        icon: Icons.check_circle_rounded,
        topColor: Color(0xFFE4F3E6),
        bottomColor: Color(0xFFCBE8CF),
        borderColor: Color(0xFF98C99F),
        textColor: Color(0xFF1F6A33),
      );
    }
    if (balance >= 300) {
      return const _LogisticsDieselTankStatus(
        label: 'Solicitar',
        helper: 'Entre 300 L y 600 L',
        icon: Icons.warning_amber_rounded,
        topColor: Color(0xFFF8F0D8),
        bottomColor: Color(0xFFF0E0A6),
        borderColor: Color(0xFFD8C06B),
        textColor: Color(0xFF886100),
      );
    }
    return const _LogisticsDieselTankStatus(
      label: 'Crítico',
      helper: 'Abajo de 300 L',
      icon: Icons.error_rounded,
      topColor: Color(0xFFF6DFDD),
      bottomColor: Color(0xFFEAC0BC),
      borderColor: Color(0xFFD39892),
      textColor: Color(0xFF8C2922),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _tankStatus;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 920;
        final cards = <Widget>[
          _LogisticsDieselHighlightCard(
            title: 'Saldo actual de diesel',
            value: _loading
                ? 'Cargando...'
                : '${_fmtDashboardLiters(_totalBalance)} L',
            helper: _loading
                ? 'Leyendo historial de compras y solicitudes'
                : 'Comprados ${_fmtDashboardLiters(_totalPurchased)} L · Solicitados ${_fmtDashboardLiters(_totalRequested)} L',
            icon: Icons.local_gas_station_rounded,
            topColor: const Color(0xFFE7ECF2),
            bottomColor: const Color(0xFFD8E0EA),
            borderColor: const Color(0xFFB7C4D3),
            textColor: kLogisticsSilverTextPrimary,
            onTap: widget.onOpenSource,
          ),
          _LogisticsDieselHighlightCard(
            title: 'Estatus del tanque',
            value: _loading ? 'Calculando...' : status.label,
            helper: _loading
                ? 'Esperando lectura del saldo actual'
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
    return _LogisticsDashboardWidgetShortcut(
      onTap: widget.onOpenSource,
      child: ContractGlassCard(
        blurSigma: 7,
        elevation: 20,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: kLogisticsModuleGradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: kLogisticsSilverBorder.withValues(alpha: 0.82),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
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
                        const Text(
                          'Resumen de Viajes y Servicios',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: kLogisticsSilverTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dashboardFormatLongDateEs(_selectedDate),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: kLogisticsSilverTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_items.length} servicio${_items.length == 1 ? '' : 's'}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: kLogisticsSilverTextMuted,
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
                  gradient: kLogisticsCapsuleGradient,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kLogisticsSilverDivider),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'EMPRESA',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: kLogisticsSilverTextPrimary,
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
                          color: kLogisticsSilverTextPrimary,
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
                          color: kLogisticsSilverTextPrimary,
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
                    ? const Center(
                        child: Text(
                          'No hay servicios para la fecha seleccionada.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: kLogisticsSilverTextSecondary,
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
                              color: Colors.white.withValues(alpha: 0.74),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: kLogisticsSilverBorderLight.withValues(
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
                                    style: const TextStyle(
                                      fontSize: 12.4,
                                      fontWeight: FontWeight.w800,
                                      color: kLogisticsSilverTextPrimary,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    item.operator,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12.2,
                                      fontWeight: FontWeight.w700,
                                      color: kLogisticsSilverTextSecondary,
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
  final Future<void> Function()? onOpenServicesSource;

  const _LogisticsWeeklyDriverCharts({
    required this.width,
    this.preferSideBySide = false,
    this.chartHeight = 350,
    this.onOpenDieselSource,
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
  List<_LogisticsDriverMetricRow> _tripRows = <_LogisticsDriverMetricRow>[];
  Timer? _timer;
  RealtimeChannel? _dieselRealtime;
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

      final driverNamesById = <String, String>{};
      for (final row in (results[2] as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        final id = (map['id'] ?? '').toString().trim();
        final label = (map['full_name'] ?? '').toString().trim();
        if (id.isEmpty || label.isEmpty) continue;
        driverNamesById[id] = label;
      }

      final tripsByDriver = <String, double>{};
      for (final row in (results[1] as List)) {
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
    final stacked = widget.preferSideBySide
        ? widget.width < 760
        : widget.width < 1240;
    final loading = _loadingMeta || _loadingWeek;
    final weekLabel = _dashboardFormatWeekRangeEs(_selectedWeekStart);
    final weekSubtitle = _availableWeeks.isEmpty
        ? 'Sin semanas con datos todavía'
        : 'Navega entre semanas reales del historial del área';

    final charts = <Widget>[
      SizedBox(
        height: widget.chartHeight,
        child: _LogisticsVerticalBarChartCard(
          title: 'Litros solicitados por chofer',
          subtitle: 'Suma semanal tomada desde Consumo de Diesel',
          loading: loading,
          rows: _litersRows,
          emptyMessage: 'Todavía no hay litros solicitados en esta semana.',
          valueFormatter: (value) => '${_fmtDashboardLiters(value)} L',
          barTopColor: const Color(0xFFAFBAC7),
          barBottomColor: const Color(0xFF7B8795),
          axisLabel: 'Litros',
          onOpenSource: widget.onOpenDieselSource,
        ),
      ),
      SizedBox(
        height: widget.chartHeight,
        child: _LogisticsVerticalBarChartCard(
          title: 'Número de viajes por chofer',
          subtitle: 'Conteo semanal tomado desde Viajes y Servicios',
          loading: loading,
          rows: _tripRows,
          emptyMessage: 'Todavía no hay viajes asignados en esta semana.',
          valueFormatter: (value) => _fmtDashboardCount(value),
          barTopColor: const Color(0xFF8FA4B8),
          barBottomColor: const Color(0xFF546272),
          axisLabel: 'Viajes',
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
              gradient: kLogisticsCapsuleGradient,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kLogisticsSilverDivider),
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
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: kLogisticsSilverTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        weekSubtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11.8,
                          fontWeight: FontWeight.w700,
                          color: kLogisticsSilverTextMuted,
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
        if (stacked)
          Column(children: [charts[0], const SizedBox(height: 12), charts[1]])
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: charts[0]),
              const SizedBox(width: 12),
              Expanded(child: charts[1]),
            ],
          ),
      ],
    );
  }
}

class _LogisticsVerticalBarChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool loading;
  final List<_LogisticsDriverMetricRow> rows;
  final String emptyMessage;
  final String Function(double value) valueFormatter;
  final Color barTopColor;
  final Color barBottomColor;
  final String axisLabel;
  final Future<void> Function()? onOpenSource;

  const _LogisticsVerticalBarChartCard({
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.rows,
    required this.emptyMessage,
    required this.valueFormatter,
    required this.barTopColor,
    required this.barBottomColor,
    required this.axisLabel,
    this.onOpenSource,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return _LogisticsDashboardWidgetShortcut(
      onTap: onOpenSource,
      child: ContractGlassCard(
        blurSigma: 7,
        elevation: 18,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Container(
          decoration: BoxDecoration(
            gradient: kLogisticsModuleGradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: kLogisticsSilverBorder.withValues(alpha: 0.80),
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
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : rows.isEmpty
                    ? Center(
                        child: Text(
                          emptyMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kLogisticsSilverTextSecondary,
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final maxValue = _dashboardMaxMetricValue(rows);
                          final count = rows.isEmpty ? 1 : rows.length;
                          final gutter = count <= 4
                              ? 12.0
                              : count <= 6
                              ? 10.0
                              : count <= 8
                              ? 8.0
                              : 6.0;
                          final slotWidth = math.max(
                            18.0,
                            (constraints.maxWidth / count) - gutter,
                          );
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                axisLabel,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: kLogisticsSilverTextMuted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    for (final row in rows)
                                      Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: gutter / 2,
                                          ),
                                          child: _LogisticsDriverBarColumn(
                                            row: row,
                                            maxValue: maxValue,
                                            valueFormatter: valueFormatter,
                                            barTopColor: barTopColor,
                                            barBottomColor: barBottomColor,
                                            slotWidth: slotWidth,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
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

class _LogisticsDriverBarColumn extends StatelessWidget {
  final _LogisticsDriverMetricRow row;
  final double maxValue;
  final String Function(double value) valueFormatter;
  final Color barTopColor;
  final Color barBottomColor;
  final double slotWidth;

  const _LogisticsDriverBarColumn({
    required this.row,
    required this.maxValue,
    required this.valueFormatter,
    required this.barTopColor,
    required this.barBottomColor,
    required this.slotWidth,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = maxValue <= 0 ? 0.0 : (row.value / maxValue).clamp(0.0, 1.0);
    final barHeight = 34 + (ratio * 126);
    final tooltipMessage = '${row.label}\n${valueFormatter(row.value)}';
    final valueFontSize = slotWidth < 34
        ? 8.2
        : slotWidth < 48
        ? 9.3
        : 11.5;
    final labelFontSize = slotWidth < 34
        ? 7.4
        : slotWidth < 48
        ? 8.6
        : slotWidth < 64
        ? 10.0
        : 11.6;
    final labelHeight = slotWidth < 40 ? 40.0 : 34.0;
    final labelMaxLines = slotWidth < 40 ? 3 : 2;
    final barWidth = math.min(44.0, math.max(12.0, slotWidth * 0.56));
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: slotWidth < 38 ? 0 : 2),
      child: Column(
        children: [
          SizedBox(
            height: 18,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                valueFormatter(row.value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.w900,
                  color: kLogisticsSilverTextPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
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
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    width: barWidth,
                    height: barHeight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [barTopColor, barBottomColor],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: barBottomColor.withValues(alpha: 0.24),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: labelHeight,
            child: Text(
              _dashboardCompactPersonLabel(row.label, slotWidth: slotWidth),
              maxLines: labelMaxLines,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: labelFontSize,
                fontWeight: FontWeight.w800,
                color: kLogisticsSilverTextSecondary,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
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

class _LogisticsDieselHighlightCard extends StatelessWidget {
  final String title;
  final String value;
  final String helper;
  final IconData icon;
  final Color topColor;
  final Color bottomColor;
  final Color borderColor;
  final Color textColor;
  final Future<void> Function()? onTap;

  const _LogisticsDieselHighlightCard({
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
              colors: [topColor, bottomColor],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
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
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
                child: Icon(icon, size: 24, color: textColor),
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
                        color: textColor.withValues(alpha: 0.88),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      helper,
                      style: TextStyle(
                        fontSize: 12.6,
                        fontWeight: FontWeight.w700,
                        color: textColor.withValues(alpha: 0.82),
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
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: enabled ? kLogisticsCapsuleGradient : null,
          color: enabled ? null : Colors.white.withValues(alpha: 0.36),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled
                ? kLogisticsSilverDivider
                : kLogisticsSilverBorder.withValues(alpha: 0.54),
          ),
        ),
        child: Icon(
          icon,
          size: 17,
          color: enabled
              ? kLogisticsSilverTextPrimary
              : kLogisticsSilverTextMuted,
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

String _dashboardCompactPersonLabel(String raw, {double? slotWidth}) {
  final words = raw
      .trim()
      .split(RegExp(r'\s+'))
      .where((element) => element.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return '—';
  if ((slotWidth ?? 999) < 36) {
    if (words.length == 1) {
      final word = words.first;
      return word.length <= 3 ? word : word.substring(0, 3);
    }
    final first = words.first.isEmpty ? '' : words.first[0];
    final second = words.length > 1 && words[1].isNotEmpty ? words[1][0] : '';
    return '$first\n$second';
  }
  if ((slotWidth ?? 999) < 52 && words.length > 1) {
    final second = words[1].isEmpty ? '' : words[1][0];
    return '${words.first}\n$second.';
  }
  if (words.length == 1) return words.first;
  return '${words.first}\n${words[1]}';
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
