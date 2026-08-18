import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../dashboard/general_dashboard_page.dart';
import '../logistica/logistics_dashboard_page.dart';
import '../management_reports/management_supervision_page.dart';
import '../management_reports/management_reports_registry.dart';
import '../management_reports/management_reports_widgets.dart';
import '../maintenance/maintenance_page.dart';
import '../maintenance/purchase_orders_page.dart';
import '../shared/archetypes/dashboard/empty_area_dashboard.dart';
import '../shared/page_routes.dart';
import '../shared/production_daily_summary_widget.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/number_formatters.dart';
import 'gerencia_area_chrome.dart';
import 'gerencia_bale_weekly_tracking_page.dart';
import 'gerencia_bale_weekly_tracking_store.dart';
import 'gerencia_theme.dart';

class GerenciaDashboardPage extends StatefulWidget {
  final bool instantOpen;

  const GerenciaDashboardPage({super.key, this.instantOpen = false});

  @override
  State<GerenciaDashboardPage> createState() => _GerenciaDashboardPageState();
}

class _GerenciaDashboardPageState extends State<GerenciaDashboardPage> {
  static const Duration _kSilentReloadInterval = Duration(seconds: 60);

  bool _loading = true;
  bool _loadingHistory = true;
  bool _refreshing = false;
  bool _refreshingHistory = false;
  bool _pendingHistoryReload = false;
  late DateTime _visibleWeekStartDate;
  GerenciaBaleWeeklyTrackingBundle? _bundle;
  List<GerenciaBaleWeeklyHistorySnapshot> _history = const [];
  Timer? _reloadTimer;
  RealtimeChannel? _dashboardRefreshChannel;

  static final EmptyAreaDashboardConfig _config = EmptyAreaDashboardConfig(
    dashboardLabel: 'Gerencia',
    sidePanelLabel: 'Gerencia',
    headerTitleColor: Colors.white,
    heroEyebrow: 'GERENCIA',
    heroTitle: 'Seguimiento semanal de producción y embarque.',
    heroSubtitle:
        'Consulta el avance semanal de pacas con base en el plan capturado y la ejecución real registrada en Operación.',
    emptyTitle: 'Pulso semanal',
    emptySubtitle:
        'Producción, embarque y estado semanal consolidados para lectura ejecutiva.',
    contractTitle: 'Gerencia',
    contractSubtitle: 'Superficie operativa de Gerencia.',
    contractFootnote: 'Plan semanal manual contra producción y salidas reales.',
    heroCardBorderColor: Color(0x40FF9FA7),
    heroCardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xF35B1623), Color(0xF325080F)],
    ),
    heroEyebrowColor: Color(0xFFFFC8CF),
    heroTitleColor: Color(0xFFFFFFFF),
    heroSubtitleColor: Color(0xCCFFE4E8),
    workspaceBodyColor: Color(0xCCFFE4E8),
    emptyStateSurfaceColor: Color(0xCC19070D),
    emptyStateBorderColor: Color(0x40FF9AA6),
    emptyStateIconColor: Color(0xFFFF9FA7),
    emptyStateBodyColor: Color(0xCCFFE4E8),
    contractPanelColor: Color(0xF3200A11),
    contractActionColor: Color(0x994A1520),
    contractActionHoverColor: Color(0xCC6A2130),
    contractActionIconColor: Color(0xFFFFC3CB),
    contractFootnoteColor: Color(0xCCFFE4E8),
    placeholderCardColor: Color(0xE0230B12),
    placeholderCardIconColor: Color(0xFFFFB4BC),
    placeholderCardDescriptionColor: Color(0xCCFFE4E8),
    placeholderCardArrowColor: Color(0xFFFFB4BC),
    tokens: gerenciaAreaTokens,
    ink: Color(0xFFFFFFFF),
    mutedInk: Color(0xCCFFE4E8),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFF7A87), Color(0xFFD84B5B)],
    ),
    panelGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xE6250B12), Color(0xE61D0810)],
    ),
    accentGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFB23346), Color(0xFF4A1520)],
    ),
    backgroundGradientColors: [
      Color(0xFF12060A),
      Color(0xFF2E0C15),
      Color(0xFF5D1824),
    ],
    topLeftBlobColors: [Color(0xFF3A0F17), Color(0xFF16070B)],
    topRightBlobColors: [Color(0x66D65767), Color(0x11220B10)],
    bottomLeftBlobColors: [Color(0x33B93D50), Color(0x11FFD7DD)],
    pillarGradientColors: [Color(0x66FFB4BC), Color(0xFF1A0A10)],
    areaItems: <DashboardNavAction>[],
    showContractPanel: false,
    showPlaceholderCards: false,
    sidePanelBuilder: _buildGerenciaSidePanel,
  );

  @override
  void initState() {
    super.initState();
    _visibleWeekStartDate =
        GerenciaBaleWeeklyTrackingStore.currentWeekStartDate();
    unawaited(_load());
    unawaited(_loadHistory());
    _reloadTimer = Timer.periodic(_kSilentReloadInterval, (_) {
      unawaited(_load(silent: true, forceRefresh: true));
      unawaited(_loadHistory());
    });
    _dashboardRefreshChannel = Supabase.instance.client
        .channel('gerencia-dashboard-refresh')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory_movements_v2',
          callback: (_) {
            unawaited(_load(silent: true, forceRefresh: true));
            unawaited(_loadHistory());
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'gerencia_bale_weekly_plan_lines',
          callback: (_) {
            unawaited(_load(silent: true, forceRefresh: true));
            unawaited(_loadHistory());
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _reloadTimer?.cancel();
    _dashboardRefreshChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load({bool silent = false, bool forceRefresh = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (!silent || _bundle == null) {
      setState(() => _loading = true);
    }
    try {
      final bundle = await GerenciaBaleWeeklyTrackingStore.loadWeek(
        _visibleWeekStartDate,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _loading = false;
      });
      unawaited(_loadHistory());
    } catch (_) {
      if (!mounted) return;
      if (!silent || _bundle == null) {
        setState(() => _loading = false);
      }
    } finally {
      _refreshing = false;
    }
  }

  bool get _isViewingCurrentWeek =>
      _visibleWeekStartDate ==
      GerenciaBaleWeeklyTrackingStore.currentWeekStartDate();

  bool get _canGoToNextWeek => _visibleWeekStartDate.isBefore(
    GerenciaBaleWeeklyTrackingStore.currentWeekStartDate(),
  );

  Future<void> _changeVisibleWeek(DateTime nextWeekStartDate) async {
    final normalized = GerenciaBaleWeeklyTrackingStore.normalizeWeekStartDate(
      nextWeekStartDate,
    );
    if (normalized == _visibleWeekStartDate) return;
    if (mounted) {
      setState(() {
        _visibleWeekStartDate = normalized;
      });
    } else {
      _visibleWeekStartDate = normalized;
    }
    await _load(forceRefresh: true);
  }

  Future<void> _openPreviousWeek() async {
    await _changeVisibleWeek(
      _visibleWeekStartDate.subtract(const Duration(days: 7)),
    );
  }

  Future<void> _openCurrentWeek() async {
    await _changeVisibleWeek(
      GerenciaBaleWeeklyTrackingStore.currentWeekStartDate(),
    );
  }

  Future<void> _openNextWeek() async {
    if (!_canGoToNextWeek) return;
    await _changeVisibleWeek(
      _visibleWeekStartDate.add(const Duration(days: 7)),
    );
  }

  Future<void> _loadHistory() async {
    if (_refreshingHistory) {
      _pendingHistoryReload = true;
      return;
    }
    _refreshingHistory = true;
    if (mounted) {
      setState(() => _loadingHistory = true);
    }
    try {
      final history = await GerenciaBaleWeeklyTrackingStore.loadRecentHistory();
      if (!mounted) return;
      setState(() {
        _history = history;
        _loadingHistory = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingHistory = false);
    } finally {
      _refreshingHistory = false;
      if (_pendingHistoryReload && mounted) {
        _pendingHistoryReload = false;
        unawaited(_loadHistory());
      }
    }
  }

  Future<void> _openWeeklyTracking() async {
    await Navigator.of(context).push(
      appPageRoute(
        page: GerenciaBaleWeeklyTrackingPage(
          instantOpen: true,
          initialWeekStartDate: _visibleWeekStartDate,
        ),
      ),
    );
    await _load();
  }

  Future<void> _openMaintenanceViewer() async {
    await Navigator.of(context).push(
      appPageRoute(
        page: const MaintenancePage(viewerMode: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openPurchaseOrdersViewer() async {
    await Navigator.of(context).push(
      appPageRoute(
        page: const PurchaseOrdersPage(viewerMode: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openManagementSupervision() async {
    await Navigator.of(context).push(
      appPageRoute(
        page: const ManagementSupervisionPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return EmptyAreaDashboardPage(
      instantOpen: widget.instantOpen,
      config: _config.copyWith(
        areaItems: [
          const DashboardNavAction(
            title: 'Dashboard Gerencia',
            subtitle: 'Pulso ejecutivo semanal',
            icon: Icons.space_dashboard_rounded,
            current: true,
            onTap: _noop,
          ),
          DashboardNavAction(
            title: 'Seguimiento Semanal de Pacas',
            subtitle: 'Plan, real y detalle diario',
            icon: Icons.stacked_line_chart_rounded,
            onTap: _openWeeklyTracking,
          ),
          DashboardNavAction(
            title: 'Supervisión por Áreas',
            subtitle: 'Reportes diarios y viernes para junta',
            icon: Icons.fact_check_rounded,
            onTap: _openManagementSupervision,
          ),
        ],
        workspaceBuilder: (context, config, width) => _GerenciaWorkspace(
          width: width,
          loading: _loading,
          loadingHistory: _loadingHistory,
          bundle: _bundle,
          history: _history,
          isViewingCurrentWeek: _isViewingCurrentWeek,
          canGoToNextWeek: _canGoToNextWeek,
          onOpenPreviousWeek: _openPreviousWeek,
          onOpenCurrentWeek: _openCurrentWeek,
          onOpenNextWeek: _openNextWeek,
          onOpenWeeklyTracking: _openWeeklyTracking,
          onOpenMaintenanceViewer: _openMaintenanceViewer,
          onOpenPurchaseOrdersViewer: _openPurchaseOrdersViewer,
          onOpenManagementSupervision: _openManagementSupervision,
        ),
      ),
    );
  }
}

Widget _buildGerenciaSidePanel(
  BuildContext context,
  EmptyAreaDashboardConfig config,
  bool canReturnToDirection,
  List<DashboardNavAction> accessItems,
  List<DashboardNavAction> areaItems,
) {
  return GerenciaAreaSidePanel(
    label: config.sidePanelLabel,
    canReturnToDirection: canReturnToDirection,
    areaItems: areaItems,
    accessItems: accessItems,
  );
}

class _GerenciaWorkspace extends StatelessWidget {
  final double width;
  final bool loading;
  final bool loadingHistory;
  final GerenciaBaleWeeklyTrackingBundle? bundle;
  final List<GerenciaBaleWeeklyHistorySnapshot> history;
  final bool isViewingCurrentWeek;
  final bool canGoToNextWeek;
  final Future<void> Function() onOpenPreviousWeek;
  final Future<void> Function() onOpenCurrentWeek;
  final Future<void> Function() onOpenNextWeek;
  final Future<void> Function() onOpenWeeklyTracking;
  final Future<void> Function() onOpenMaintenanceViewer;
  final Future<void> Function() onOpenPurchaseOrdersViewer;
  final Future<void> Function() onOpenManagementSupervision;

  const _GerenciaWorkspace({
    required this.width,
    required this.loading,
    required this.loadingHistory,
    required this.bundle,
    required this.history,
    required this.isViewingCurrentWeek,
    required this.canGoToNextWeek,
    required this.onOpenPreviousWeek,
    required this.onOpenCurrentWeek,
    required this.onOpenNextWeek,
    required this.onOpenWeeklyTracking,
    required this.onOpenMaintenanceViewer,
    required this.onOpenPurchaseOrdersViewer,
    required this.onOpenManagementSupervision,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return ContractGlassCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumen ejecutivo de la semana',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: tokens.onGlass,
                      ),
                    ),
                    if (bundle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Semana ${_isoWeekNumber(bundle!.weekStartDate)} · ${_shortDate(bundle!.weekStartDate)} - ${_shortDate(bundle!.weekEndDate)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xCCFFE4E8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _DashboardWeekNavigator(
                isViewingCurrentWeek: isViewingCurrentWeek,
                canGoToNextWeek: canGoToNextWeek,
                onOpenPreviousWeek: onOpenPreviousWeek,
                onOpenCurrentWeek: onOpenCurrentWeek,
                onOpenNextWeek: onOpenNextWeek,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (loading)
            const SizedBox(
              height: 280,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (bundle == null)
            _WorkspaceMessage(
              icon: Icons.warning_amber_rounded,
              title: 'No fue posible cargar Gerencia',
              body:
                  'No se pudo leer el pulso semanal. Revisa la conexión y vuelve a intentar.',
            )
          else
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _SummaryMetricCard(
                  title: 'Producción',
                  value:
                      '${formatDecimal(bundle!.totalProductionActual, decimals: 0)} pacas',
                  subtitle:
                      'Meta ${formatDecimal(bundle!.currentPlan?.totalProductionTarget ?? 0, decimals: 0)} · Necesarias ${formatDecimal(bundle!.totalProductionNeed, decimals: 0)}',
                  tone: const Color(0xFFFF8E9B),
                  icon: Icons.precision_manufacturing_rounded,
                ),
                _SummaryMetricCard(
                  title: 'Embarque',
                  value:
                      '${formatDecimal(bundle!.totalShipmentActual, decimals: 0)} pacas',
                  subtitle:
                      'Meta ${formatDecimal(bundle!.currentPlan?.totalShipmentTarget ?? 0, decimals: 0)} · Necesarias ${formatDecimal(bundle!.totalShipmentNeed, decimals: 0)}',
                  tone: const Color(0xFFFFC07A),
                  icon: Icons.local_shipping_rounded,
                ),
                _SummaryMetricCard(
                  title: 'Estado semanal',
                  value: _weekHeadline(bundle!),
                  subtitle: _weekDetail(bundle!),
                  tone: _weekTone(bundle!),
                  icon: Icons.monitor_heart_outlined,
                ),
              ],
            ),
          if (!loading &&
              bundle != null &&
              isViewingCurrentWeek &&
              bundle!.totalProductionActual <= 0 &&
              bundle!.totalShipmentActual <= 0) ...[
            const SizedBox(height: 14),
            _DashboardWeekHintCard(onOpenPreviousWeek: onOpenPreviousWeek),
          ],
          if (!loading) ...[
            const SizedBox(height: 18),
            if (isViewingCurrentWeek)
              const ProductionDailySummaryWidget(
                title: 'Producción diaria consolidada',
                subtitle:
                    'Semana actual por turno para seguimiento ejecutivo. Revuelta C1 y C2 se separan desde el comentario de Producción.',
                palette: ProductionDailySummaryPalette(
                  surface: Color(0x5916070D),
                  border: Color(0x40FF9AA6),
                  accent: Color(0xFFFF9FA7),
                  accentSoft: Color(0xFFFFE4E8),
                  text: Color(0xFFFFFFFF),
                  mutedText: Color(0xCCFFE4E8),
                  gridLine: Color(0x30FFB5BE),
                  highlightSurface: Color(0xA319070D),
                ),
              )
            else
              const _DashboardWeekContextCard(),
          ],
          if (!loading) ...[
            const SizedBox(height: 18),
            const _DashboardSectionHeading(
              title: 'Flujo Material Operativo de Dirección',
              subtitle:
                  'Entradas y salidas consolidadas del frente operativo para lectura ejecutiva.',
            ),
            const SizedBox(height: 12),
            const DirectionOperationalMaterialFlowWidget(),
            const SizedBox(height: 18),
            const _DashboardSectionHeading(
              title: 'Widgets de Logística',
              subtitle:
                  'Resumen de viajes, control diario, combustibles y número de viajes para lectura de Gerencia.',
            ),
            const SizedBox(height: 12),
            const LogisticsManagementExecutiveSection(),
            const SizedBox(height: 18),
            ManagementAreaReportPanel(
              areaKey: ManagementAreaKey.gerencia,
              subtitleOverride:
                  'Desde aquí Gerencia puede generar el corte semanal del área y modelar el ritual que después replicarán los encargados.',
              showOpenHubButton: true,
              showReportActions: false,
              onOpenSupervisionHub: onOpenManagementSupervision,
            ),
            const SizedBox(height: 18),
            _OperationsViewerAccessSection(
              width: width,
              onOpenMaintenanceViewer: onOpenMaintenanceViewer,
              onOpenPurchaseOrdersViewer: onOpenPurchaseOrdersViewer,
            ),
          ],
          if (!loading && bundle != null) ...[
            const SizedBox(height: 18),
            _HistoricTrackingCard(history: history, loading: loadingHistory),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            style: contractSecondaryButtonStyle(context),
            onPressed: onOpenWeeklyTracking,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Abrir seguimiento semanal'),
          ),
        ],
      ),
    );
  }
}

class _DashboardWeekNavigator extends StatelessWidget {
  final bool isViewingCurrentWeek;
  final bool canGoToNextWeek;
  final Future<void> Function() onOpenPreviousWeek;
  final Future<void> Function() onOpenCurrentWeek;
  final Future<void> Function() onOpenNextWeek;

  const _DashboardWeekNavigator({
    required this.isViewingCurrentWeek,
    required this.canGoToNextWeek,
    required this.onOpenPreviousWeek,
    required this.onOpenCurrentWeek,
    required this.onOpenNextWeek,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        _DashboardWeekNavButton(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Semana anterior',
          onPressed: onOpenPreviousWeek,
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(
              color: isViewingCurrentWeek
                  ? Colors.white.withValues(alpha: 0.18)
                  : const Color(0x66FFE4E8),
            ),
            backgroundColor: isViewingCurrentWeek
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            minimumSize: const Size(0, 44),
          ),
          onPressed: isViewingCurrentWeek ? null : onOpenCurrentWeek,
          icon: const Icon(Icons.today_rounded, size: 18),
          label: Text(isViewingCurrentWeek ? 'Semana actual' : 'Ir a actual'),
        ),
        _DashboardWeekNavButton(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Semana siguiente',
          onPressed: canGoToNextWeek ? onOpenNextWeek : null,
        ),
      ],
    );
  }
}

class _DashboardWeekNavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Future<void> Function()? onPressed;

  const _DashboardWeekNavButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.03),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          minimumSize: const Size(44, 44),
        ),
        icon: Icon(icon),
      ),
    );
  }
}

class _DashboardWeekHintCard extends StatelessWidget {
  final Future<void> Function() onOpenPreviousWeek;

  const _DashboardWeekHintCard({required this.onOpenPreviousWeek});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x40FF9AA6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, color: Color(0xFFFFC07A)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Todavía no hay movimiento en esta semana. Si buscas embarques recientes, revisa la semana anterior.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xCCFFE4E8),
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            style: contractSecondaryButtonStyle(context),
            onPressed: onOpenPreviousWeek,
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('Semana anterior'),
          ),
        ],
      ),
    );
  }
}

class _DashboardWeekContextCard extends StatelessWidget {
  const _DashboardWeekContextCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x40FF9AA6)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFFFFC07A)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'El tablero diario consolidado permanece anclado a la semana actual. Para revisar otra semana con detalle, abre Seguimiento semanal.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xCCFFE4E8),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoricTrackingCard extends StatelessWidget {
  final List<GerenciaBaleWeeklyHistorySnapshot> history;
  final bool loading;

  const _HistoricTrackingCard({required this.history, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x40FF9AA6)),
        ),
        child: const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (history.isEmpty) {
      return const _WorkspaceMessage(
        icon: Icons.timeline_rounded,
        title: 'Sin histórico aún',
        body:
            'En cuanto existan más semanas capturadas en Seguimiento, aquí aparecerá la visualización histórica.',
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x40FF9AA6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Histórico del seguimiento',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Visualización de semanas recientes con real contra meta en producción y embarque.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xCCFFE4E8),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < history.length; index++) ...[
            _HistoricWeekRow(snapshot: history[index]),
            if (index != history.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _HistoricWeekRow extends StatelessWidget {
  final GerenciaBaleWeeklyHistorySnapshot snapshot;

  const _HistoricWeekRow({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Semana ${_isoWeekNumber(snapshot.weekStartDate)} · ${_shortDate(snapshot.weekStartDate)} - ${_shortDate(snapshot.weekEndDate)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFFE4E8),
            ),
          ),
          const SizedBox(height: 12),
          _HistoricLane(
            label: 'Producción',
            actual: snapshot.productionActualBales,
            target: snapshot.productionTargetBales,
            ratio: snapshot.productionRatio,
            tone: const Color(0xFFFF8E9B),
          ),
          const SizedBox(height: 10),
          _HistoricLane(
            label: 'Embarque',
            actual: snapshot.shipmentActualBales,
            target: snapshot.shipmentTargetBales,
            ratio: snapshot.shipmentRatio,
            tone: const Color(0xFFFFC07A),
          ),
        ],
      ),
    );
  }
}

class _HistoricLane extends StatelessWidget {
  final String label;
  final int actual;
  final int target;
  final double? ratio;
  final Color tone;

  const _HistoricLane({
    required this.label,
    required this.actual,
    required this.target,
    required this.ratio,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final progress = ratio == null
        ? 0.0
        : (ratio! < 0 ? 0.0 : (ratio! > 1.0 ? 1.0 : ratio!));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$label · ${formatDecimal(actual, decimals: 0)} / ${formatDecimal(target, decimals: 0)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xCCFFE4E8),
                ),
              ),
            ),
            Text(
              ratio == null
                  ? 'sin meta'
                  : '${formatDecimal(ratio! * 100, decimals: 0)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: tone,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: progress,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(tone),
          ),
        ),
      ],
    );
  }
}

class _DashboardSectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;

  const _DashboardSectionHeading({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xCCFFE4E8),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _OperationsViewerAccessSection extends StatelessWidget {
  final double width;
  final Future<void> Function() onOpenMaintenanceViewer;
  final Future<void> Function() onOpenPurchaseOrdersViewer;

  const _OperationsViewerAccessSection({
    required this.width,
    required this.onOpenMaintenanceViewer,
    required this.onOpenPurchaseOrdersViewer,
  });

  @override
  Widget build(BuildContext context) {
    final compact = width < 980;
    final cards = <Widget>[
      _OperationsViewerAccessCard(
        icon: Icons.build_circle_outlined,
        title: 'Órdenes de Trabajo',
        subtitle: 'Visualizador de Operaciones',
        body:
            'Seguimiento ejecutivo de OT sin acceso al resto de los módulos operativos.',
        accent: const Color(0xFFFF9FA7),
        ctaLabel: 'Abrir OT',
        onTap: onOpenMaintenanceViewer,
      ),
      _OperationsViewerAccessCard(
        icon: Icons.shopping_cart_checkout_rounded,
        title: 'Órdenes de Compra',
        subtitle: 'Visualizador de Operaciones',
        body:
            'Seguimiento ejecutivo de Compras OT sin autorizar, rechazar ni abrir otras superficies de Operación.',
        accent: const Color(0xFFFFC07A),
        ctaLabel: 'Abrir Compras OT',
        onTap: onOpenPurchaseOrdersViewer,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _DashboardSectionHeading(
          title: 'Accesos de Operaciones',
          subtitle:
              'Gerencia solo puede abrir estas dos páginas en modo visualizador.',
        ),
        const SizedBox(height: 12),
        if (compact)
          Column(children: [cards[0], const SizedBox(height: 12), cards[1]])
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 12),
              Expanded(child: cards[1]),
            ],
          ),
      ],
    );
  }
}

class _OperationsViewerAccessCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String body;
  final Color accent;
  final String ctaLabel;
  final Future<void> Function() onTap;

  const _OperationsViewerAccessCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.accent,
    required this.ctaLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.26)),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xCCFFE4E8),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: contractSecondaryButtonStyle(context),
            onPressed: onTap,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(ctaLabel),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color tone;
  final IconData icon;

  const _SummaryMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.tone,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 252,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tone.withValues(alpha: 0.26)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: tone),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFFE4E8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: tone,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xCCFFE4E8),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _WorkspaceMessage({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 280),
      decoration: BoxDecoration(
        color: const Color(0xCC19070D),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x40FF9AA6)),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 38, color: const Color(0xFFFFC07A)),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Text(
                  body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xCCFFE4E8),
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _weekHeadline(GerenciaBaleWeeklyTrackingBundle bundle) {
  if (!bundle.hasPlan) {
    return 'Sin meta semanal';
  }
  final revuelto = _revueltoLine(bundle);
  if (revuelto != null &&
      revuelto.shipmentTargetBales > 0 &&
      revuelto.shipmentActualBales < revuelto.shipmentEstimatedBales) {
    return 'Semana atrasada en revuelto';
  }
  if ((bundle.currentPlan?.totalShipmentTarget ?? 0) > 0 &&
      bundle.totalShipmentActual < bundle.totalShipmentEstimated) {
    return 'Semana con riesgo en embarque';
  }
  return 'Semana en línea';
}

String _weekDetail(GerenciaBaleWeeklyTrackingBundle bundle) {
  if (!bundle.hasPlan) {
    return 'Ya existe lectura real, pero todavía no hay meta semanal formal en Gerencia.';
  }
  final revuelto = _revueltoLine(bundle);
  if (revuelto != null &&
      revuelto.shipmentTargetBales > 0 &&
      revuelto.shipmentActualBales < revuelto.shipmentEstimatedBales) {
    return 'Revuelto concentra hoy el desvío principal y debe revisarse primero.';
  }
  if ((bundle.currentPlan?.totalShipmentTarget ?? 0) > 0 &&
      bundle.totalShipmentActual < bundle.totalShipmentEstimated) {
    return 'El embarque va por debajo del ritmo esperado de la semana.';
  }
  return 'La lectura ejecutiva no detecta hoy un desvío crítico dominante.';
}

Color _weekTone(GerenciaBaleWeeklyTrackingBundle bundle) {
  final headline = _weekHeadline(bundle);
  if (headline == 'Semana atrasada en revuelto' ||
      headline == 'Semana con riesgo en embarque') {
    return const Color(0xFFFFA0AA);
  }
  if (headline == 'Sin meta semanal') {
    return const Color(0xFFFFD89E);
  }
  return const Color(0xFF89E8A8);
}

GerenciaBaleWeeklyLineSummary? _revueltoLine(
  GerenciaBaleWeeklyTrackingBundle bundle,
) {
  for (final line in bundle.lineSummaries) {
    if (line.baleType.key == 'revuelto') {
      return line;
    }
  }
  return null;
}

String _shortDate(DateTime date) {
  const months = <String>[
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${date.day} ${months[date.month - 1]}';
}

int _isoWeekNumber(DateTime date) {
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final firstThursday = DateTime(thursday.year, 1, 4);
  return 1 + ((thursday.difference(firstThursday).inDays) ~/ 7);
}

Future<void> _noop() async {}
