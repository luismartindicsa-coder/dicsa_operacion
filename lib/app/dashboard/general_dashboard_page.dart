import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_navigation.dart';
import '../commercial/commercial_dashboard_page.dart';
import '../commercial/commercial_store.dart';
import '../contabilidad/contabilidad_dashboard_page.dart';
import '../contabilidad/contabilidad_trade_analysis_page.dart';
import '../compras/compras_dashboard_page.dart';
import '../direction/direction_cash_entries_exits_page.dart';
import '../direction/direction_cash_taxonomy_page.dart';
import '../direction/direction_maintenance_page.dart';
import '../direction/direction_menudeo_analysis_page.dart';
import '../direction/direction_operations_repository.dart';
import '../direction/direction_purchase_orders_page.dart';
import '../direction/direction_theme.dart';
import '../finanzas/finanzas_bank_accounts_store.dart';
import '../finanzas/finanzas_due_alerts_store.dart';
import '../finanzas/finanzas_dashboard_page.dart';
import '../gerencia/gerencia_bale_weekly_tracking_store.dart';
import '../gerencia/gerencia_dashboard_page.dart';
import '../hr/human_resources_dashboard_page.dart';
import '../logistica/logistics_dashboard_page.dart';
import '../maintenance/maintenance_statuses.dart';
import '../mayoreo/mayoreo_dashboard_preview_page.dart';
import '../menudeo/menudeo_dashboard_page.dart';
import '../shared/app_error_reporter.dart';
import '../shared/app_shell.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/archetypes/auxiliary_surfaces/confirmation_dialog.dart';
import '../shared/direction_vault/direction_vault_repository.dart';
import '../shared/production_daily_summary_widget.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/utils/number_formatters.dart';
import 'dashboard_page.dart';

const double _kGeneralDashboardTitleMinWidth = 440;
const double _kDirectionExecutiveWidgetWidth = 394;
const double _kDirectionExecutiveWidgetHeight = 428;
const double _kDirectionVaultDeposits = 40350;
const double _kDirectionVaultExpenses = 8850;
const int _kDirectionMaterialFlowLookbackDays = 42;

class GeneralDashboardPage extends StatefulWidget {
  final bool instantOpen;

  const GeneralDashboardPage({super.key, this.instantOpen = false});

  @override
  State<GeneralDashboardPage> createState() => _GeneralDashboardPageState();
}

class _GeneralDashboardPageState extends State<GeneralDashboardPage> {
  static const Duration _kFinanzasDueAlertDelay = Duration(seconds: 2);
  bool _directionExpanded = true;
  bool _areasExpanded = true;
  bool _menuOverlayOpen = false;
  bool _finanzasDueAlertQueued = false;
  FinanzasDueAlertsSummary _finanzasDueAlertsSummary =
      const FinanzasDueAlertsSummary.empty();

  @override
  void initState() {
    super.initState();
    unawaited(_refreshFinanzasDueAlertsSummary());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(_kFinanzasDueAlertDelay, () {
        if (!mounted) return;
        unawaited(_presentFinanzasDueAlertIfNeeded());
      });
    });
  }

  Future<FinanzasDueAlertsSummary> _refreshFinanzasDueAlertsSummary() async {
    final summary = await FinanzasDueAlertsStore.loadSummary();
    if (!mounted) return summary;
    setState(() => _finanzasDueAlertsSummary = summary);
    return summary;
  }

  Future<void> _presentFinanzasDueAlertIfNeeded() async {
    if (!mounted || _finanzasDueAlertQueued) return;
    _finanzasDueAlertQueued = true;
    try {
      final summary = await _refreshFinanzasDueAlertsSummary();
      if (!mounted || summary.totalCount <= 0 || summary.items.isEmpty) return;
      if (!FinanzasDueAlertsSessionGate.registerPresentation(
        FinanzasDueAlertsSessionScope.directionDashboard,
      )) {
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return _DirectionFinanzasDueNotificationDialog(
            summary: summary,
            visibleItems: summary.items.toList(growable: false),
            onOpenFinanzas: () async {
              Navigator.of(dialogContext).pop();
              await _openFinanzasDashboard();
            },
          );
        },
      );
    } catch (_) {
      // Keep the dashboard usable even if the notification cannot be loaded.
    }
  }

  Future<void> _openFinanzasDueAlertsDialog() async {
    try {
      final summary = await _refreshFinanzasDueAlertsSummary();
      if (!mounted || summary.totalCount <= 0 || summary.items.isEmpty) {
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return _DirectionFinanzasDueNotificationDialog(
            summary: summary,
            visibleItems: summary.items.toList(growable: false),
            onOpenFinanzas: () async {
              Navigator.of(dialogContext).pop();
              await _openFinanzasDashboard();
            },
          );
        },
      );
    } catch (_) {
      // Keep the dashboard usable even if the notification cannot be loaded.
    }
  }

  Future<void> _logout() async {
    final ok = await showContractConfirmationDialog(
      context,
      title: 'Cerrar sesión',
      content: '¿Seguro que deseas cerrar tu sesión?',
      confirmText: 'Cerrar sesión',
      tokens: directionAreaTokens,
    );
    if (ok != true || !mounted) return;
    await signOutAndRouteToLogin(context);
  }

  Future<void> _openOperationalDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const DashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openRetailDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MenudeoDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openMayoreoPreviewDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MayoreoDashboardPreviewPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openComprasDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const ComprasDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openFinanzasDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const FinanzasDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openContabilidadDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const ContabilidadDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openHumanResourcesDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const HumanResourcesDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openLogisticsDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const LogisticsDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openGerenciaDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const GerenciaDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openCommercialDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const CommercialDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openDirectionCashWorkspace() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const DirectionCashEntriesExitsPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openDirectionCashCatalog() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const DirectionCashTaxonomyPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openDirectionMenudeoAnalysis() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const DirectionMenudeoAnalysisPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openDirectionTradeAnalysis() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const ContabilidadTradeAnalysisPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openDirectionPurchaseOrders() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const DirectionPurchaseOrdersPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openDirectionMaintenance() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const DirectionMaintenancePage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AreaThemeScope(
      tokens: directionAreaTokens,
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape &&
              _menuOverlayOpen) {
            setState(() => _menuOverlayOpen = false);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AppShell(
          background: const DirectionExecutiveBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 6,
          padding: const EdgeInsets.fromLTRB(28, 14, 18, 18),
          leadingBuilder: (_, _) => Row(
            children: [
              _GeneralHeaderButton(
                label: _menuOverlayOpen ? 'Cerrar navegación' : 'Navegación',
                icon: _menuOverlayOpen
                    ? Icons.close_rounded
                    : Icons.menu_rounded,
                onTap: () async {
                  if (!mounted) return;
                  setState(() => _menuOverlayOpen = !_menuOverlayOpen);
                },
              ),
            ],
          ),
          centerBuilder: (_, contentAnim) =>
              _GeneralDashboardBrand(contentAnim: contentAnim),
          trailingBuilder: (_, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _GeneralHeaderButton(
                label: 'Pendientes',
                icon: Icons.notifications_none_rounded,
                notificationCount: _finanzasDueAlertsSummary.totalCount,
                onTap: _openFinanzasDueAlertsDialog,
              ),
              const SizedBox(width: 10),
              _GeneralHeaderButton(
                label: 'Cerrar sesión',
                icon: Icons.logout_rounded,
                onTap: _logout,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 8, 8),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final menu = _GeneralDashboardSideMenu(
      directionExpanded: _directionExpanded,
      areasExpanded: _areasExpanded,
      onOpenGeneralDashboard: () async {},
      onOpenDirectionCashWorkspace: _openDirectionCashWorkspace,
      onOpenDirectionCashCatalog: _openDirectionCashCatalog,
      onOpenDirectionMenudeoAnalysis: _openDirectionMenudeoAnalysis,
      onOpenDirectionTradeAnalysis: _openDirectionTradeAnalysis,
      onOpenOperationalDashboard: _openOperationalDashboard,
      onOpenMenudeo: _openRetailDashboard,
      onOpenMayoreo: _openMayoreoPreviewDashboard,
      onOpenCompras: _openComprasDashboard,
      onOpenFinanzas: _openFinanzasDashboard,
      onOpenContabilidad: _openContabilidadDashboard,
      onOpenLogistics: _openLogisticsDashboard,
      onOpenGerencia: _openGerenciaDashboard,
      onOpenHumanResources: _openHumanResourcesDashboard,
      onOpenCommercial: _openCommercialDashboard,
      onToggleDirectionExpanded: () =>
          setState(() => _directionExpanded = !_directionExpanded),
      onToggleAreasExpanded: () =>
          setState(() => _areasExpanded = !_areasExpanded),
    );

    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 56, right: 2, bottom: 8),
          child: _DirectionDashboardCanvas(
            onOpenVault: _openDirectionCashWorkspace,
            onOpenOperationalDashboard: _openOperationalDashboard,
            onOpenMenudeoAnalysis: _openDirectionMenudeoAnalysis,
            onOpenFinanzasDashboard: _openFinanzasDashboard,
            onOpenContabilidad: _openContabilidadDashboard,
            onOpenLogistics: _openLogisticsDashboard,
            onOpenTradeAnalysis: _openDirectionTradeAnalysis,
            onOpenPurchaseOrders: _openDirectionPurchaseOrders,
            onOpenMaintenance: _openDirectionMaintenance,
            onOpenHumanResources: _openHumanResourcesDashboard,
            onOpenGerencia: _openGerenciaDashboard,
            onOpenCommercial: _openCommercialDashboard,
          ),
        ),
      ),
    );

    const overlayWidth = 320.0;

    return Stack(
      children: [
        content,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_menuOverlayOpen,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              opacity: _menuOverlayOpen ? 1 : 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!mounted) return;
                  setState(() => _menuOverlayOpen = false);
                },
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          left: _menuOverlayOpen ? 0 : -(overlayWidth + 12),
          top: 0,
          width: overlayWidth,
          bottom: 0,
          child: IgnorePointer(
            ignoring: !_menuOverlayOpen,
            child: SingleChildScrollView(child: menu),
          ),
        ),
      ],
    );
  }
}

class _DirectionDashboardCanvas extends StatelessWidget {
  final Future<void> Function() onOpenVault;
  final Future<void> Function() onOpenOperationalDashboard;
  final Future<void> Function() onOpenMenudeoAnalysis;
  final Future<void> Function() onOpenFinanzasDashboard;
  final Future<void> Function() onOpenContabilidad;
  final Future<void> Function() onOpenLogistics;
  final Future<void> Function() onOpenTradeAnalysis;
  final Future<void> Function() onOpenPurchaseOrders;
  final Future<void> Function() onOpenMaintenance;
  final Future<void> Function() onOpenHumanResources;
  final Future<void> Function() onOpenGerencia;
  final Future<void> Function() onOpenCommercial;

  const _DirectionDashboardCanvas({
    required this.onOpenVault,
    required this.onOpenOperationalDashboard,
    required this.onOpenMenudeoAnalysis,
    required this.onOpenFinanzasDashboard,
    required this.onOpenContabilidad,
    required this.onOpenLogistics,
    required this.onOpenTradeAnalysis,
    required this.onOpenPurchaseOrders,
    required this.onOpenMaintenance,
    required this.onOpenHumanResources,
    required this.onOpenGerencia,
    required this.onOpenCommercial,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DIRECCION',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.2,
              color: kDirectionOliveGlow,
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1220),
              child: _DirectionMoneyMetricsSection(
                onOpenVault: onOpenVault,
                onOpenMenudeoAnalysis: onOpenMenudeoAnalysis,
                onOpenFinanzasDashboard: onOpenFinanzasDashboard,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 18,
            runSpacing: 18,
            children: [
              SizedBox(
                width: _kDirectionExecutiveWidgetWidth,
                height: _kDirectionExecutiveWidgetHeight,
                child: _DirectionPurchaseOrdersDashboardSummary(
                  onOpenPurchaseOrders: onOpenPurchaseOrders,
                ),
              ),
              SizedBox(
                width: _kDirectionExecutiveWidgetWidth,
                height: _kDirectionExecutiveWidgetHeight,
                child: _DirectionMaintenanceDashboardSummary(
                  onOpenMaintenance: onOpenMaintenance,
                ),
              ),
              SizedBox(
                width: _kDirectionExecutiveWidgetWidth,
                height: _kDirectionExecutiveWidgetHeight,
                child: _DirectionTradeDashboardSummary(
                  onOpenTradeAnalysis: onOpenTradeAnalysis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              const servicesWidth = 420.0;
              const sectionGap = 14.0;
              const servicesSectionHeight = 560.0;
              final canSplit =
                  constraints.maxWidth >= servicesWidth + 760 + sectionGap;
              final productionWidget = const ProductionDailySummaryWidget(
                title: 'Producción diaria consolidada',
                subtitle:
                    'Semana actual por turno para lectura ejecutiva. Revuelta C1 y C2 se separan desde el comentario de Producción.',
                palette: ProductionDailySummaryPalette(
                  surface: Color(0x33191F08),
                  border: Color(0x40D8E38A),
                  accent: kDirectionOliveGlow,
                  accentSoft: kDirectionIvory,
                  text: kDirectionSurfaceText,
                  mutedText: kDirectionMutedText,
                  gridLine: Color(0x33D8E38A),
                  highlightSurface: Color(0x3D313812),
                ),
              );
              final servicesWidget = _DeferredDashboardSection(
                delay: const Duration(milliseconds: 700),
                minHeight: 320,
                child: _DirectionOperationalServicesSummary(
                  onOpenOperationalDashboard: onOpenOperationalDashboard,
                ),
              );
              if (!canSplit) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    productionWidget,
                    const SizedBox(height: 14),
                    SizedBox(
                      width: servicesWidth,
                      height: servicesSectionHeight,
                      child: servicesWidget,
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: productionWidget),
                  const SizedBox(width: sectionGap),
                  SizedBox(
                    width: servicesWidth,
                    height: servicesSectionHeight,
                    child: servicesWidget,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          const _DeferredDashboardSection(
            delay: Duration(milliseconds: 1200),
            minHeight: 360,
            child: _DirectionMaterialFlowChartsSection(),
          ),
          const SizedBox(height: 20),
          const Text(
            'ÁREAS DE ANÁLISIS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
              color: kDirectionOliveMist,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              SizedBox(
                width: 1288,
                child: _DeferredDashboardSection(
                  delay: const Duration(milliseconds: 950),
                  minHeight: 260,
                  child: _DirectionGerenciaDashboardSummary(
                    onOpenGerencia: onOpenGerencia,
                  ),
                ),
              ),
              SizedBox(
                width: 420,
                child: _DirectionAnalysisEntryCard(
                  title: 'Recursos Humanos',
                  subtitle:
                      'Nomina, incidencias, vacaciones y cruces de pago con Finanzas bajo formulas trazables.',
                  badge: 'Area nueva',
                  icon: Icons.badge_rounded,
                  onTap: onOpenHumanResources,
                ),
              ),
              SizedBox(
                width: 420,
                child: _DirectionAnalysisEntryCard(
                  title: 'Logística',
                  subtitle:
                      'Nueva entrada homologada del área para rutas, asignación diaria, flotilla y control operativo.',
                  badge: 'Area nueva',
                  icon: Icons.local_shipping_rounded,
                  onTap: onOpenLogistics,
                ),
              ),
              SizedBox(
                width: 420,
                child: _DirectionAnalysisEntryCard(
                  title: 'Contabilidad',
                  subtitle:
                      'Nueva area de solo lectura para flujo, gastos, estado de resultados y utilidad confiable.',
                  badge: 'Area nueva',
                  icon: Icons.account_balance_rounded,
                  onTap: onOpenContabilidad,
                ),
              ),
              SizedBox(
                width: 420,
                child: _DirectionCommercialFollowUpsSummary(
                  onOpenCommercial: onOpenCommercial,
                ),
              ),
            ],
          ),
          const SizedBox(height: 320),
        ],
      ),
    );
  }
}

class _DeferredDashboardSection extends StatefulWidget {
  final Duration delay;
  final double minHeight;
  final Widget child;

  const _DeferredDashboardSection({
    required this.delay,
    required this.minHeight,
    required this.child,
  });

  @override
  State<_DeferredDashboardSection> createState() =>
      _DeferredDashboardSectionState();
}

class _DeferredDashboardSectionState extends State<_DeferredDashboardSection> {
  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (!mounted) return;
      setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_visible) return widget.child;
    return SizedBox(
      height: widget.minHeight,
      child: _DirectionGlassPanel(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        borderRadius: BorderRadius.circular(28),
        blurSigma: 26,
        fillColor: kDirectionOliveDeep.withValues(alpha: 0.18),
        borderColor: Colors.white.withValues(alpha: 0.16),
        shadowColor: Colors.black.withValues(alpha: 0.10),
        edgeHighlightColor: Colors.white.withValues(alpha: 0.42),
        bevelShadowColor: Colors.black.withValues(alpha: 0.08),
        glowColor: kDirectionOliveGlow.withValues(alpha: 0.06),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
      ),
    );
  }
}

class _DirectionPurchaseOrdersDashboardSummary extends StatefulWidget {
  final Future<void> Function() onOpenPurchaseOrders;

  const _DirectionPurchaseOrdersDashboardSummary({
    required this.onOpenPurchaseOrders,
  });

  @override
  State<_DirectionPurchaseOrdersDashboardSummary> createState() =>
      _DirectionPurchaseOrdersDashboardSummaryState();
}

class _DirectionPurchaseOrdersDashboardSummaryState
    extends State<_DirectionPurchaseOrdersDashboardSummary> {
  final DirectionOperationsRepository _repo = DirectionOperationsRepository();
  DirectionPurchaseOrdersSummary? _summary;
  bool _loading = true;
  bool _hovering = false;
  bool _refreshing = false;
  bool _pendingReload = false;
  Timer? _refreshTimer;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _requestReload(showLoader: true);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 90),
      (_) => _requestReload(),
    );
    _channel = Supabase.instance.client
        .channel('direction-dashboard-purchase-orders-alerts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'maintenance_purchase_orders',
          callback: (_) => _requestReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'maintenance_purchase_order_lines',
          callback: (_) => _requestReload(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  void _requestReload({bool showLoader = false}) {
    if (!mounted) return;
    if (_refreshing) {
      _pendingReload = true;
      return;
    }
    unawaited(_load(silent: !showLoader));
  }

  Future<void> _load({bool silent = false}) async {
    if (_refreshing) {
      _pendingReload = true;
      return;
    }
    _refreshing = true;
    if (!silent && mounted) {
      setState(() => _loading = true);
    }
    try {
      final summary = await _repo.loadPurchaseOrdersSummary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    } finally {
      _refreshing = false;
      if (_pendingReload && mounted) {
        _pendingReload = false;
        unawaited(_load(silent: true));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final items =
        summary?.pendingItems ?? const <DirectionPurchasePendingItem>[];
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        offset: _hovering ? const Offset(0, -0.014) : Offset.zero,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          scale: _hovering ? 1.01 : 1.0,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () async => widget.onOpenPurchaseOrders(),
              child: _DirectionGlassPanel(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                borderRadius: BorderRadius.circular(28),
                blurSigma: 30,
                fillColor: kDirectionOliveDeep.withValues(alpha: 0.24),
                borderColor: Colors.white.withValues(
                  alpha: _hovering ? 0.34 : 0.28,
                ),
                shadowColor: Colors.black.withValues(
                  alpha: _hovering ? 0.18 : 0.14,
                ),
                edgeHighlightColor: Colors.white.withValues(
                  alpha: _hovering ? 0.78 : 0.70,
                ),
                bevelShadowColor: Colors.black.withValues(alpha: 0.14),
                glowColor: kDirectionOliveGlow.withValues(
                  alpha: _hovering ? 0.18 : 0.12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DirectionPurchaseOrdersOverviewPanel(
                      summary: summary,
                      loading: _loading,
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: _DirectionPurchaseOrdersMiniTable(
                        items: items,
                        loading: _loading,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectionCompactSummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _DirectionCompactSummaryChip({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: accent.withValues(alpha: 0.10),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionPurchaseOrdersOverviewPanel extends StatelessWidget {
  final DirectionPurchaseOrdersSummary? summary;
  final bool loading;

  const _DirectionPurchaseOrdersOverviewPanel({
    required this.summary,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: kDirectionOliveGlow.withValues(alpha: 0.14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: const Text(
            'COMPRAS OT',
            style: TextStyle(
              color: kDirectionOliveGlow,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Pendientes por autorizar',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          summary == null
              ? 'Cargando el resumen ejecutivo.'
              : summary!.pendingCount == 0
              ? 'No hay compras OT pendientes.'
              : 'Vista rápida para decidir sin abrir la pantalla completa.',
          style: const TextStyle(
            color: kDirectionSurfaceText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DirectionCompactSummaryChip(
                label: 'Pendientes',
                value: summary == null ? '...' : '${summary!.pendingCount}',
                accent: kDirectionOliveGlow,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DirectionCompactSummaryChip(
                label: 'Críticas',
                value: summary == null ? '...' : '${summary!.criticalCount}',
                accent: kDirectionDanger,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _DirectionCompactSummaryChip(
                label: 'Monto',
                value: summary == null
                    ? '...'
                    : formatMoney(summary!.pendingAmount),
                accent: kDirectionWarning,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DirectionCompactSummaryChip(
                label: 'Más antigua',
                value: summary == null
                    ? '...'
                    : summary!.oldestHours <= 0
                    ? '0 h'
                    : '${summary!.oldestHours.round()} h',
                accent: kDirectionOliveMist,
              ),
            ),
          ],
        ),
        if (loading && summary == null) ...[
          const SizedBox(height: 14),
          const Text(
            'Cargando Compras OT...',
            style: TextStyle(
              color: kDirectionMutedText,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _DirectionPurchaseOrdersMiniTable extends StatelessWidget {
  final List<DirectionPurchasePendingItem> items;
  final bool loading;

  const _DirectionPurchaseOrdersMiniTable({
    required this.items,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 150;
        final rowLimit = compact ? 1 : 3;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(14, compact ? 10 : 12, 14, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Órdenes prioritarias',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '${items.length} visibles',
                      style: const TextStyle(
                        color: kDirectionMutedText,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (!compact)
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Row(
                    children: [
                      Expanded(child: _DirectionTableHeaderCell('Folio')),
                      Expanded(child: _DirectionTableHeaderCell('Solicita')),
                      Expanded(
                        child: _DirectionTableHeaderCell(
                          'Monto',
                          alignment: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        child: _DirectionTableHeaderCell(
                          'Horas',
                          alignment: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: loading && items.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : items.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'No hay compras OT pendientes por autorizar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: kDirectionMutedText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: items
                            .take(rowLimit)
                            .map(
                              (item) => _DirectionPurchaseSummaryRow(
                                item: item,
                                compact: compact,
                              ),
                            )
                            .toList(growable: false),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DirectionMaintenanceDashboardSummary extends StatefulWidget {
  final Future<void> Function() onOpenMaintenance;

  const _DirectionMaintenanceDashboardSummary({
    required this.onOpenMaintenance,
  });

  @override
  State<_DirectionMaintenanceDashboardSummary> createState() =>
      _DirectionMaintenanceDashboardSummaryState();
}

class _DirectionMaintenanceDashboardSummaryState
    extends State<_DirectionMaintenanceDashboardSummary> {
  final DirectionOperationsRepository _repo = DirectionOperationsRepository();
  DirectionMaintenanceSummary? _summary;
  bool _loading = true;
  bool _hovering = false;
  bool _refreshing = false;
  bool _pendingReload = false;
  Timer? _refreshTimer;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _requestReload(showLoader: true);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 90),
      (_) => _requestReload(),
    );
    _channel = Supabase.instance.client
        .channel('direction-dashboard-maintenance-summary')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'maintenance_orders',
          callback: (_) => _requestReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'maintenance_materials',
          callback: (_) => _requestReload(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  void _requestReload({bool showLoader = false}) {
    if (!mounted) return;
    if (_refreshing) {
      _pendingReload = true;
      return;
    }
    unawaited(_load(silent: !showLoader));
  }

  Future<void> _load({bool silent = false}) async {
    if (_refreshing) {
      _pendingReload = true;
      return;
    }
    _refreshing = true;
    if (!silent && mounted) {
      setState(() => _loading = true);
    }
    try {
      final summary = await _repo.loadMaintenanceSummary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    } finally {
      _refreshing = false;
      if (_pendingReload && mounted) {
        _pendingReload = false;
        unawaited(_load(silent: true));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final items =
        summary?.pendingItems ?? const <DirectionMaintenancePendingItem>[];
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        offset: _hovering ? const Offset(0, -0.014) : Offset.zero,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          scale: _hovering ? 1.01 : 1.0,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () async => widget.onOpenMaintenance(),
              child: _DirectionGlassPanel(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                borderRadius: BorderRadius.circular(28),
                blurSigma: 30,
                fillColor: kDirectionOliveDeep.withValues(alpha: 0.24),
                borderColor: Colors.white.withValues(
                  alpha: _hovering ? 0.34 : 0.28,
                ),
                shadowColor: Colors.black.withValues(
                  alpha: _hovering ? 0.18 : 0.14,
                ),
                edgeHighlightColor: Colors.white.withValues(
                  alpha: _hovering ? 0.78 : 0.70,
                ),
                bevelShadowColor: Colors.black.withValues(alpha: 0.14),
                glowColor: kDirectionOliveGlow.withValues(
                  alpha: _hovering ? 0.18 : 0.12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DirectionMaintenanceOverviewPanel(
                      summary: summary,
                      loading: _loading,
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: _DirectionMaintenanceMiniTable(
                        items: items,
                        loading: _loading,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectionMaintenanceOverviewPanel extends StatelessWidget {
  final DirectionMaintenanceSummary? summary;
  final bool loading;

  const _DirectionMaintenanceOverviewPanel({
    required this.summary,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: kDirectionOliveGlow.withValues(alpha: 0.14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: const Text(
            'MANTENIMIENTO OT',
            style: TextStyle(
              color: kDirectionOliveGlow,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'OT de seguimiento',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          summary == null
              ? 'Cargando el resumen ejecutivo.'
              : summary!.openCount == 0
              ? 'No hay OT abiertas.'
              : 'Vista rápida de órdenes abiertas, riesgos y esperas.',
          style: const TextStyle(
            color: kDirectionSurfaceText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DirectionCompactSummaryChip(
                label: 'Abiertas',
                value: summary == null ? '...' : '${summary!.openCount}',
                accent: kDirectionOliveGlow,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DirectionCompactSummaryChip(
                label: 'Críticas',
                value: summary == null ? '...' : '${summary!.criticalCount}',
                accent: kDirectionDanger,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _DirectionCompactSummaryChip(
                label: 'Sin mov.',
                value: summary == null ? '...' : '${summary!.staleCount}',
                accent: kDirectionWarning,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DirectionCompactSummaryChip(
                label: 'Espera',
                value: summary == null
                    ? '...'
                    : '${summary!.waitingDirectionCount}',
                accent: kDirectionOliveMist,
              ),
            ),
          ],
        ),
        if (loading && summary == null) ...[
          const SizedBox(height: 14),
          const Text(
            'Cargando Mantenimiento OT...',
            style: TextStyle(
              color: kDirectionMutedText,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _DirectionMaintenanceMiniTable extends StatelessWidget {
  final List<DirectionMaintenancePendingItem> items;
  final bool loading;

  const _DirectionMaintenanceMiniTable({
    required this.items,
    required this.loading,
  });

  String _statusLabel(String status) {
    return maintenanceStatusShortLabel(status);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 150;
        final rowLimit = compact ? 1 : 3;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(14, compact ? 10 : 12, 14, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'OT prioritarias',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '${items.length} visibles',
                      style: const TextStyle(
                        color: kDirectionMutedText,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (!compact)
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Row(
                    children: [
                      Expanded(child: _DirectionTableHeaderCell('Folio')),
                      Expanded(child: _DirectionTableHeaderCell('Estatus')),
                      Expanded(
                        child: _DirectionTableHeaderCell(
                          'Horas',
                          alignment: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        child: _DirectionTableHeaderCell(
                          'Impacto',
                          alignment: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: loading && items.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : items.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'No hay OT abiertas por seguir.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: kDirectionMutedText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: items
                            .take(rowLimit)
                            .map(
                              (item) => _DirectionMaintenanceSummaryRow(
                                item: item,
                                statusLabel: _statusLabel(item.status),
                                compact: compact,
                              ),
                            )
                            .toList(growable: false),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DirectionMaintenanceSummaryRow extends StatelessWidget {
  final DirectionMaintenancePendingItem item;
  final String statusLabel;
  final bool compact;

  const _DirectionMaintenanceSummaryRow({
    required this.item,
    required this.statusLabel,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final ageAccent = item.ageHours >= 48
        ? kDirectionDanger
        : item.ageHours >= 24
        ? kDirectionWarning
        : kDirectionOliveGlow;
    final impactLabel = item.impact.trim().toLowerCase() == 'paro_total'
        ? 'Total'
        : item.impact.trim().toLowerCase() == 'paro_parcial'
        ? 'Parcial'
        : item.priority.trim().toLowerCase() == 'alta'
        ? 'Alta'
        : 'Normal';
    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        compact ? 10 : 12,
        14,
        compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _DirectionTableValueCell(
              item.folio.isEmpty ? 'Sin folio' : item.folio,
            ),
          ),
          Expanded(child: _DirectionTableValueCell(statusLabel)),
          Expanded(
            child: Text(
              item.ageHours <= 0 ? '0 h' : '${item.ageHours.round()} h',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: ageAccent,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: _DirectionTableValueCell(
              impactLabel,
              alignment: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionTableHeaderCell extends StatelessWidget {
  final String label;
  final TextAlign alignment;

  const _DirectionTableHeaderCell(
    this.label, {
    this.alignment = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: alignment,
      style: const TextStyle(
        color: kDirectionOliveMist,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.9,
      ),
    );
  }
}

class _DirectionPurchaseSummaryRow extends StatelessWidget {
  final DirectionPurchasePendingItem item;
  final bool compact;

  const _DirectionPurchaseSummaryRow({
    required this.item,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final ageAccent = item.ageHours >= 48
        ? kDirectionDanger
        : item.ageHours >= 24
        ? kDirectionWarning
        : kDirectionOliveGlow;
    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        compact ? 10 : 14,
        18,
        compact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _DirectionTableValueCell(
              item.folio.isEmpty ? 'Sin folio' : item.folio,
            ),
          ),
          Expanded(
            flex: 2,
            child: _DirectionTableValueCell(
              item.requestedByName.isEmpty
                  ? 'Sin captura'
                  : item.requestedByName,
            ),
          ),
          Expanded(
            flex: 2,
            child: _DirectionTableValueCell(
              item.vendorName.isEmpty ? 'Sin proveedor' : item.vendorName,
            ),
          ),
          Expanded(
            child: _DirectionTableValueCell(
              formatMoney(item.total),
              alignment: TextAlign.right,
            ),
          ),
          Expanded(
            child: Text(
              item.ageHours <= 0 ? '0 h' : '${item.ageHours.round()} h',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: ageAccent,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionTableValueCell extends StatelessWidget {
  final String value;
  final TextAlign alignment;

  const _DirectionTableValueCell(this.value, {this.alignment = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: alignment,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _DirectionTradeDashboardSummary extends StatefulWidget {
  final Future<void> Function() onOpenTradeAnalysis;

  const _DirectionTradeDashboardSummary({required this.onOpenTradeAnalysis});

  @override
  State<_DirectionTradeDashboardSummary> createState() =>
      _DirectionTradeDashboardSummaryState();
}

class _DirectionTradeDashboardSummaryState
    extends State<_DirectionTradeDashboardSummary> {
  List<_DirectionTradeMonthPoint> _points = const <_DirectionTradeMonthPoint>[];
  bool _loading = true;
  bool _hovering = false;
  bool _refreshing = false;
  bool _pendingReload = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _requestReload(showLoader: true);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 90),
      (_) => _requestReload(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _requestReload({bool showLoader = false}) {
    if (!mounted) return;
    if (_refreshing) {
      _pendingReload = true;
      return;
    }
    unawaited(_load(silent: !showLoader));
  }

  Future<void> _load({bool silent = false}) async {
    if (_refreshing) {
      _pendingReload = true;
      return;
    }
    _refreshing = true;
    if (!silent && mounted) {
      setState(() => _loading = true);
    }
    try {
      final events = await CommercialStore.loadRecentMarketEvents();
      final points = _buildTradeMonthPoints(events);
      if (!mounted) return;
      setState(() {
        _points = points;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    } finally {
      _refreshing = false;
      if (_pendingReload && mounted) {
        _pendingReload = false;
        unawaited(_load(silent: true));
      }
    }
  }

  List<_DirectionTradeMonthPoint> _buildTradeMonthPoints(
    List<CommercialMarketEventRecord> events,
  ) {
    final datedEvents = events
        .where((event) => event.eventAt != null)
        .toList(growable: false);
    if (datedEvents.isEmpty) return const <_DirectionTradeMonthPoint>[];

    final sortedDates =
        datedEvents
            .map((event) => DateTime(event.eventAt!.year, event.eventAt!.month))
            .toList(growable: false)
          ..sort();
    final latestMonth = sortedDates.last;
    final firstMonthInWindow = DateTime(
      latestMonth.year,
      latestMonth.month - 5,
    );

    final byMonth = <DateTime, ({double buyAmount, double sellAmount})>{};
    for (final event in datedEvents) {
      final eventAt = event.eventAt!;
      final monthKey = DateTime(eventAt.year, eventAt.month);
      if (monthKey.isBefore(firstMonthInWindow) ||
          monthKey.isAfter(latestMonth)) {
        continue;
      }
      final current = byMonth[monthKey] ?? (buyAmount: 0.0, sellAmount: 0.0);
      final flow = event.flow.trim().toLowerCase();
      if (flow == 'purchase' || flow == 'buy' || flow == 'compra') {
        byMonth[monthKey] = (
          buyAmount: current.buyAmount + event.amountTotal,
          sellAmount: current.sellAmount,
        );
      } else {
        byMonth[monthKey] = (
          buyAmount: current.buyAmount,
          sellAmount: current.sellAmount + event.amountTotal,
        );
      }
    }

    final sortedMonths = byMonth.keys.toList()..sort();
    return sortedMonths
        .map((month) {
          final amounts = byMonth[month]!;
          return _DirectionTradeMonthPoint(
            month: month,
            buyAmount: amounts.buyAmount,
            sellAmount: amounts.sellAmount,
          );
        })
        .toList(growable: false)
      ..sort((a, b) => a.month.compareTo(b.month));
  }

  @override
  Widget build(BuildContext context) {
    final visiblePoints = _points;
    final current = visiblePoints.isEmpty ? null : visiblePoints.last;
    final best = visiblePoints.isEmpty
        ? null
        : (visiblePoints.toList()
                ..sort((a, b) => b.grossProfit.compareTo(a.grossProfit)))
              .first;
    final totalGross = visiblePoints.fold<double>(
      0,
      (sum, point) => sum + point.grossProfit,
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        offset: _hovering ? const Offset(0, -0.014) : Offset.zero,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          scale: _hovering ? 1.01 : 1.0,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () async => widget.onOpenTradeAnalysis(),
              child: _DirectionGlassPanel(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                borderRadius: BorderRadius.circular(28),
                blurSigma: 30,
                fillColor: kDirectionOliveDeep.withValues(alpha: 0.24),
                borderColor: Colors.white.withValues(
                  alpha: _hovering ? 0.34 : 0.28,
                ),
                shadowColor: Colors.black.withValues(
                  alpha: _hovering ? 0.18 : 0.14,
                ),
                edgeHighlightColor: Colors.white.withValues(
                  alpha: _hovering ? 0.78 : 0.70,
                ),
                bevelShadowColor: Colors.black.withValues(alpha: 0.14),
                glowColor: kDirectionOliveGlow.withValues(
                  alpha: _hovering ? 0.18 : 0.12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: kDirectionOliveGlow.withValues(alpha: 0.14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: const Text(
                        'COMPRA-VENTA',
                        style: TextStyle(
                          color: kDirectionOliveGlow,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Utilidad bruta mensual',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      visiblePoints.isEmpty
                          ? 'No hay datos suficientes para mostrar la tendencia.'
                          : 'Lectura de utilidad bruta total mes a mes en la ventana reciente.',
                      style: const TextStyle(
                        color: kDirectionSurfaceText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _DirectionCompactSummaryChip(
                            label: 'Mes actual',
                            value: current == null
                                ? '...'
                                : formatMoney(current.grossProfit),
                            accent: current != null && current.grossProfit >= 0
                                ? kDirectionSuccess
                                : kDirectionDanger,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DirectionCompactSummaryChip(
                            label: '6 meses',
                            value: visiblePoints.isEmpty
                                ? '...'
                                : formatMoney(totalGross),
                            accent: totalGross >= 0
                                ? kDirectionOliveGlow
                                : kDirectionWarning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _DirectionCompactSummaryChip(
                            label: 'Mejor mes',
                            value: best == null
                                ? '...'
                                : _monthShortLabel(best.month),
                            accent: kDirectionOliveMist,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DirectionCompactSummaryChip(
                            label: 'Pico',
                            value: best == null
                                ? '...'
                                : formatMoney(best.grossProfit),
                            accent: best != null && best.grossProfit >= 0
                                ? kDirectionSuccess
                                : kDirectionDanger,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: _DirectionTradeMiniChart(
                        points: visiblePoints,
                        loading: _loading,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectionFinanzasDueNotificationDialog extends StatefulWidget {
  final FinanzasDueAlertsSummary summary;
  final List<FinanzasDueAlertItem> visibleItems;
  final Future<void> Function() onOpenFinanzas;

  const _DirectionFinanzasDueNotificationDialog({
    required this.summary,
    required this.visibleItems,
    required this.onOpenFinanzas,
  });

  @override
  State<_DirectionFinanzasDueNotificationDialog> createState() =>
      _DirectionFinanzasDueNotificationDialogState();
}

class _DirectionFinanzasDueNotificationDialogState
    extends State<_DirectionFinanzasDueNotificationDialog> {
  final ScrollController _commitmentsScrollController = ScrollController();

  @override
  void dispose() {
    _commitmentsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryItem = widget.visibleItems.first;
    final accent = switch (primaryItem.severity) {
      FinanzasDueAlertSeverity.critical => const Color(0xFFFFB35C),
      FinanzasDueAlertSeverity.warning => const Color(0xFFFFD36E),
      FinanzasDueAlertSeverity.info => const Color(0xFF89F0C7),
    };
    final commitmentsListMaxHeight = MediaQuery.of(context).size.height * 0.38;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: _DirectionGlassPanel(
          padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
          borderRadius: BorderRadius.circular(34),
          fillColor: const Color(0xFF0D1E3C).withValues(alpha: 0.96),
          borderColor: accent.withValues(alpha: 0.45),
          edgeHighlightColor: Colors.white.withValues(alpha: 0.18),
          glowColor: accent.withValues(alpha: 0.18),
          shadowColor: Colors.black.withValues(alpha: 0.32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Icon(
                      Icons.notifications_active_rounded,
                      color: accent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Finanzas requiere atención',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _directionFinanzasDialogHeadline(widget.summary),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _DirectionNotificationPill(
                    label: 'Hoy: ${widget.summary.dueTodayCount}',
                  ),
                  _DirectionNotificationPill(
                    label: '2 días: ${widget.summary.dueIn2DaysCount}',
                  ),
                  _DirectionNotificationPill(
                    label: '1 semana: ${widget.summary.dueIn7DaysCount}',
                  ),
                  _DirectionNotificationPill(
                    label: 'Monto: ${formatMoney(widget.summary.totalAmount)}',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: Colors.white.withValues(alpha: 0.06),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Compromisos prioritarios',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: commitmentsListMaxHeight,
                      ),
                      child: Scrollbar(
                        controller: _commitmentsScrollController,
                        thumbVisibility: widget.visibleItems.length > 3,
                        child: SingleChildScrollView(
                          controller: _commitmentsScrollController,
                          child: Column(
                            children: [
                              for (
                                var index = 0;
                                index < widget.visibleItems.length;
                                index++
                              ) ...[
                                _DirectionFinanzasDueNotificationItemCard(
                                  item: widget.visibleItems[index],
                                  accent: accent,
                                ),
                                if (index != widget.visibleItems.length - 1)
                                  const SizedBox(height: 10),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF37E1A3),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.24),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('Después'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: widget.onOpenFinanzas,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Abrir Finanzas'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1FDE9A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 16,
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

class _DirectionFinanzasDueNotificationItemCard extends StatelessWidget {
  final FinanzasDueAlertItem item;
  final Color accent;

  const _DirectionFinanzasDueNotificationItemCard({
    required this.item,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _directionFinanzasAlertSourceLabel(item),
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.90),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.subtitle,
            style: const TextStyle(
              color: Color(0xFFD5E2FF),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${item.reminderLabel} · ${formatMoney(item.amount)}',
            style: TextStyle(
              color: accent,
              fontSize: 12.8,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionNotificationPill extends StatelessWidget {
  final String label;

  const _DirectionNotificationPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _directionFinanzasDialogHeadline(FinanzasDueAlertsSummary summary) {
  if (summary.dueTodayCount > 0) {
    return 'Hay ${summary.dueTodayCount} pagos que vencen hoy y conviene resolver en esta jornada.';
  }
  if (summary.dueIn2DaysCount > 0) {
    return 'Hay ${summary.dueIn2DaysCount} compromisos que vencen en 48 horas y ya están entrando a foco ejecutivo.';
  }
  return 'Hay ${summary.dueIn7DaysCount} compromisos entrando a la ventana semanal de preparación.';
}

String _directionFinanzasAlertSourceLabel(FinanzasDueAlertItem item) {
  switch (item.sourceType) {
    case 'FACTURA':
      return 'Factura proveedor';
    case 'PAGO_FIJO':
      return 'Pago fijo';
    case 'CONVENIO':
      return 'Convenio';
    default:
      return 'Compromiso';
  }
}

class _DirectionTradeMiniChart extends StatelessWidget {
  final List<_DirectionTradeMonthPoint> points;
  final bool loading;

  const _DirectionTradeMiniChart({required this.points, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading && points.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (points.isEmpty) {
      return const Center(
        child: Text(
          'Sin tendencia mensual todavía.',
          style: TextStyle(
            color: kDirectionMutedText,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    final maxAbs = points
        .map((point) => point.grossProfit.abs())
        .fold<double>(0, (max, value) => value > max ? value : max);
    final scaleBase = maxAbs <= 0 ? 1.0 : maxAbs;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Mes a mes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${points.length} meses',
                style: const TextStyle(
                  color: kDirectionMutedText,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: points
                  .map((point) {
                    final ratio = (point.grossProfit.abs() / scaleBase).clamp(
                      0.08,
                      1.0,
                    );
                    final color = point.grossProfit >= 0
                        ? kDirectionSuccess
                        : kDirectionDanger;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Tooltip(
                                  message:
                                      '${_monthShortLabel(point.month)} ${point.month.year}\n${formatMoney(point.grossProfit)}',
                                  waitDuration: const Duration(
                                    milliseconds: 120,
                                  ),
                                  textStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF102B2F,
                                    ).withValues(alpha: 0.96),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.14,
                                      ),
                                    ),
                                  ),
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: Container(
                                      height: 72 * ratio,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            color.withValues(alpha: 0.92),
                                            color.withValues(alpha: 0.48),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            blurRadius: 16,
                                            color: color.withValues(
                                              alpha: 0.20,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _monthShortLabel(point.month),
                              style: const TextStyle(
                                color: kDirectionSurfaceText,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionTradeMonthPoint {
  final DateTime month;
  final double buyAmount;
  final double sellAmount;

  const _DirectionTradeMonthPoint({
    required this.month,
    required this.buyAmount,
    required this.sellAmount,
  });

  double get grossProfit => sellAmount - buyAmount;
}

String _monthShortLabel(DateTime month) {
  const labels = <String>[
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];
  return labels[month.month - 1];
}

class _DirectionMaterialFlowChartsSection extends StatefulWidget {
  const _DirectionMaterialFlowChartsSection();

  @override
  State<_DirectionMaterialFlowChartsSection> createState() =>
      _DirectionMaterialFlowChartsSectionState();
}

class _DirectionMaterialFlowChartsSectionState
    extends State<_DirectionMaterialFlowChartsSection> {
  final SupabaseClient _supa = Supabase.instance.client;
  _DirectionMaterialFlowBundle? _bundle;
  bool _loading = true;
  bool _refreshing = false;
  bool _pendingReload = false;
  Timer? _refreshTimer;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _requestReload(showLoader: true);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 90),
      (_) => _requestReload(),
    );
    _channel = _supa
        .channel('direction-dashboard-material-flow-charts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory_movements_v2',
          callback: (_) => _requestReload(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  void _requestReload({bool showLoader = false}) {
    if (!mounted) return;
    if (_refreshing) {
      _pendingReload = true;
      return;
    }
    unawaited(_load(silent: !showLoader));
  }

  Future<void> _load({bool silent = false}) async {
    if (_refreshing) {
      _pendingReload = true;
      return;
    }
    _refreshing = true;
    if (!silent && mounted) {
      setState(() => _loading = true);
    }
    try {
      final startDate = DateUtils.dateOnly(
        DateTime.now().subtract(
          const Duration(days: _kDirectionMaterialFlowLookbackDays - 1),
        ),
      );
      final endDate = DateUtils.dateOnly(DateTime.now());
      final inRowsRaw = await _fetchDirectionMovementRows(
        flow: 'IN',
        inventoryLevel: 'GENERAL',
        startDate: startDate,
        endDate: endDate,
        select:
            'op_date,weight_kg,net_kg,gross_kg,tare_kg,total_amount_kg,'
            'general_material:general_material_id(code,name),'
            'source_commercial:source_commercial_material_id('
            'code,name,general_material:general_material_id(code,name))',
      );
      final outRowsRaw = await _fetchDirectionMovementRows(
        flow: 'OUT',
        inventoryLevel: 'COMMERCIAL',
        startDate: startDate,
        endDate: endDate,
        select:
            'op_date,weight_kg,net_kg,gross_kg,tare_kg,total_amount_kg,'
            'general_material:general_material_id(code,name),'
            'commercial_material:commercial_material_id('
            'code,name,general_material:general_material_id(code,name))',
      );
      final inRows = _normalizeDirectionMovementRows(
        rows: inRowsRaw,
        isIn: true,
      );
      final outRows = _normalizeDirectionMovementRows(
        rows: outRowsRaw,
        isIn: false,
      );
      final bundle = _buildDirectionMaterialFlowBundle(
        inRows: inRows,
        outRows: outRows,
        startDate: startDate,
        endDate: endDate,
      );
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    } finally {
      _refreshing = false;
      if (_pendingReload && mounted) {
        _pendingReload = false;
        unawaited(_load(silent: true));
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchDirectionMovementRows({
    required String flow,
    required String inventoryLevel,
    required DateTime startDate,
    required DateTime endDate,
    required String select,
  }) async {
    const batchSize = 1000;
    final rows = <Map<String, dynamic>>[];
    var from = 0;
    while (true) {
      final data = await _supa
          .from('inventory_movements_v2')
          .select(select)
          .eq('flow', flow)
          .eq('inventory_level', inventoryLevel)
          .gte('op_date', _directionDbDate(startDate))
          .lte('op_date', _directionDbDate(endDate))
          .order('op_date', ascending: true)
          .range(from, from + batchSize - 1);
      final batch = (data as List).cast<Map<String, dynamic>>();
      rows.addAll(batch);
      if (batch.length < batchSize) break;
      from += batchSize;
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final bundle = _bundle;
    return _DirectionGlassPanel(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      borderRadius: BorderRadius.circular(30),
      blurSigma: 28,
      fillColor: kDirectionOliveDeep.withValues(alpha: 0.28),
      borderColor: Colors.white.withValues(alpha: 0.30),
      shadowColor: Colors.black.withValues(alpha: 0.14),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.74),
      bevelShadowColor: Colors.black.withValues(alpha: 0.16),
      glowColor: kDirectionOliveGlow.withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Flujo de material operativo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Entradas y salidas consolidadas por material general. Hover sobre cada punto para ver los kg del día.',
            style: TextStyle(
              color: kDirectionSurfaceText,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (_loading && bundle == null)
            const SizedBox(
              height: 420,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (bundle == null)
            const SizedBox(
              height: 420,
              child: Center(
                child: Text(
                  'No fue posible cargar entradas y salidas de material.',
                  style: TextStyle(
                    color: kDirectionMutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final split = constraints.maxWidth >= 1020;
                final entriesCard = _DirectionMaterialLineChartCard(
                  title: 'Entradas de material',
                  subtitle:
                      'Promedio semanal recibido por material en lo que va de la semana.',
                  accent: const Color(0xFF87E08A),
                  averageRows: bundle.entryWeeklyAverages,
                  series: bundle.entrySeries,
                  loading: _loading,
                  diagnostics:
                      'Debug: ${bundle.entryRowCount} filas · ${formatDecimal(bundle.entryTotalKg, decimals: 0)} kg',
                );
                final exitsCard = _DirectionMaterialLineChartCard(
                  title: 'Salidas de material',
                  subtitle:
                      'Promedio semanal despachado por material en lo que va de la semana.',
                  accent: const Color(0xFFFFC16D),
                  averageRows: bundle.exitWeeklyAverages,
                  series: bundle.exitSeries,
                  loading: _loading,
                  diagnostics:
                      'Debug: ${bundle.exitRowCount} filas · ${formatDecimal(bundle.exitTotalKg, decimals: 0)} kg',
                );
                if (!split) {
                  return Column(
                    children: [
                      SizedBox(height: 430, child: entriesCard),
                      const SizedBox(height: 14),
                      SizedBox(height: 430, child: exitsCard),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: SizedBox(height: 430, child: entriesCard)),
                    const SizedBox(width: 14),
                    Expanded(child: SizedBox(height: 430, child: exitsCard)),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _DirectionMaterialLineChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final List<_DirectionMaterialAverageRow> averageRows;
  final List<_DirectionMaterialLineSeries> series;
  final bool loading;
  final String? diagnostics;

  const _DirectionMaterialLineChartCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.averageRows,
    required this.series,
    required this.loading,
    this.diagnostics,
  });

  @override
  Widget build(BuildContext context) {
    return _DirectionGlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      borderRadius: BorderRadius.circular(26),
      blurSigma: 26,
      fillColor: Colors.white.withValues(alpha: 0.05),
      borderColor: Colors.white.withValues(alpha: 0.18),
      shadowColor: Colors.black.withValues(alpha: 0.10),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.62),
      bevelShadowColor: Colors.black.withValues(alpha: 0.12),
      glowColor: accent.withValues(alpha: 0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: kDirectionSurfaceText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (diagnostics != null) ...[
            const SizedBox(height: 6),
            Text(
              diagnostics!,
              style: const TextStyle(
                color: Color(0xFFB7CFCC),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'Promedio semana',
            style: TextStyle(
              color: kDirectionOliveMist,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          if (averageRows.isEmpty)
            const Text(
              'Sin promedio semanal disponible todavía.',
              style: TextStyle(
                color: kDirectionMutedText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: averageRows.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final row = averageRows[index];
                  return _DirectionMaterialAverageChip(
                    label: row.label,
                    value:
                        '${formatDecimal(row.averageKgPerDay, decimals: 0)} kg/día',
                    color: row.color,
                  );
                },
              ),
            ),
          const SizedBox(height: 14),
          Expanded(
            child: _DirectionMaterialLineChart(
              series: series,
              unitLabel: 'kg',
              loading: loading,
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionMaterialAverageChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DirectionMaterialAverageChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 136,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionMaterialLineChart extends StatefulWidget {
  final List<_DirectionMaterialLineSeries> series;
  final String unitLabel;
  final bool loading;

  const _DirectionMaterialLineChart({
    required this.series,
    required this.unitLabel,
    required this.loading,
  });

  @override
  State<_DirectionMaterialLineChart> createState() =>
      _DirectionMaterialLineChartState();
}

class _DirectionMaterialLineChartState
    extends State<_DirectionMaterialLineChart> {
  static const int _visibleDays = 7;
  static const double _axisWidth = 58;
  static const double _leftPad = 12;
  static const double _rightPad = 18;
  static const double _topPad = 10;
  static const double _bottomPad = 28;

  final ScrollController _scrollController = ScrollController();
  _DirectionHoveredPointInfo? _hovered;
  bool _stickToLatest = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToLatest());
  }

  @override
  void didUpdateWidget(covariant _DirectionMaterialLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_stickToLatest) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToLatest());
    }
  }

  void _jumpToLatest() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (max > 0) {
      _scrollController.jumpTo(max);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading && widget.series.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.series.isEmpty ||
        widget.series.every((series) => series.points.isEmpty)) {
      return const Center(
        child: Text(
          'Sin datos suficientes.',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: kDirectionMutedText,
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = widget.series.first.points.length;
        final plotHeight = math.max(120.0, constraints.maxHeight - 28);
        final viewportWidth = math.max(
          120.0,
          constraints.maxWidth - _axisWidth,
        );
        final dayStep = viewportWidth / _visibleDays;
        final contentWidth = math.max(
          constraints.maxWidth - _axisWidth,
          _leftPad + _rightPad + ((count - 1) * dayStep) + 24,
        );
        final maxY = _directionLineChartMaxY(widget.series);
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: _axisWidth,
                    height: plotHeight,
                    child: CustomPaint(
                      painter: _DirectionLineChartYAxisPainter(
                        maxY: maxY,
                        topPad: _topPad,
                        bottomPad: _bottomPad,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Expanded(
                    child: MouseRegion(
                      onExit: (_) => setState(() => _hovered = null),
                      onHover: (event) {
                        final hit = _directionHitTestPoint(
                          event.localPosition,
                          viewportSize: Size(
                            constraints.maxWidth - _axisWidth,
                            plotHeight,
                          ),
                          contentWidth: contentWidth,
                          dayStep: dayStep,
                          maxY: maxY,
                        );
                        if (hit?.key == _hovered?.key) return;
                        setState(() => _hovered = hit);
                      },
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragUpdate: (details) {
                          if (!_scrollController.hasClients) return;
                          _stickToLatest = false;
                          final max =
                              _scrollController.position.maxScrollExtent;
                          if (max <= 0) return;
                          final next =
                              (_scrollController.offset - details.delta.dx)
                                  .clamp(0.0, max);
                          _scrollController.jumpTo(next);
                        },
                        onHorizontalDragStart: (_) =>
                            setState(() => _hovered = null),
                        child: Stack(
                          children: [
                            SingleChildScrollView(
                              controller: _scrollController,
                              scrollDirection: Axis.horizontal,
                              physics: const ClampingScrollPhysics(),
                              primary: false,
                              child: SizedBox(
                                width: contentWidth,
                                height: plotHeight,
                                child: CustomPaint(
                                  painter: _DirectionMaterialLineChartPainter(
                                    series: widget.series,
                                    maxY: maxY,
                                    leftPad: _leftPad,
                                    rightPad: _rightPad,
                                    topPad: _topPad,
                                    bottomPad: _bottomPad,
                                    dayStep: dayStep,
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                            if (_hovered != null)
                              Positioned(
                                left: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _hovered!.color.withValues(
                                        alpha: 0.55,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    '${_hovered!.label} · ${_hovered!.dayLabel} · ${formatDecimal(_hovered!.value, decimals: 0)} ${widget.unitLabel}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF223A39),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 24,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.series
                      .map(
                        (series) => Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: series.color,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                series.label,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF365653),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  _DirectionHoveredPointInfo? _directionHitTestPoint(
    Offset p, {
    required Size viewportSize,
    required double contentWidth,
    required double dayStep,
    required double maxY,
  }) {
    if (widget.series.isEmpty) return null;
    final count = widget.series.first.points.length;
    if (count == 0) return null;
    final left = _leftPad;
    final top = _topPad;
    final right = contentWidth - _rightPad;
    final bottom = viewportSize.height - _bottomPad;
    final xInContent =
        p.dx + (_scrollController.hasClients ? _scrollController.offset : 0);
    final yInContent = p.dy;
    if (xInContent < left ||
        xInContent > right ||
        yInContent < top ||
        yInContent > bottom) {
      return null;
    }
    final h = math.max(1.0, bottom - top);
    final dayIndex = ((xInContent - left) / dayStep).round().clamp(
      0,
      count - 1,
    );
    final x = left + (dayIndex * dayStep);
    for (var i = 0; i < widget.series.length; i++) {
      final value = widget.series[i].points[dayIndex].value;
      final y = bottom - ((value / maxY) * h);
      final distance = (Offset(x, y) - Offset(xInContent, yInContent)).distance;
      if (distance <= 10) {
        final day = widget.series[i].points[dayIndex].day;
        return _DirectionHoveredPointInfo(
          dayIndex: dayIndex,
          seriesIndex: i,
          label: widget.series[i].label,
          color: widget.series[i].color,
          value: value,
          dayLabel:
              '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}',
        );
      }
    }
    return null;
  }
}

class _DirectionMaterialLineChartPainter extends CustomPainter {
  final List<_DirectionMaterialLineSeries> series;
  final double maxY;
  final double leftPad;
  final double rightPad;
  final double topPad;
  final double bottomPad;
  final double dayStep;

  const _DirectionMaterialLineChartPainter({
    required this.series,
    required this.maxY,
    required this.leftPad,
    required this.rightPad,
    required this.topPad,
    required this.bottomPad,
    required this.dayStep,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final left = leftPad;
    final top = topPad;
    final right = size.width - rightPad;
    final bottom = size.height - bottomPad;
    final h = math.max(1.0, bottom - top);
    final count = series.first.points.length;
    final gridPaint = Paint()
      ..color = const Color(0xFFB7CFCC).withValues(alpha: 0.20)
      ..strokeWidth = 1;
    const yTicks = 5;
    for (var i = 0; i < yTicks; i++) {
      final ratio = i / (yTicks - 1);
      final y = bottom - (h * ratio);
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);
    }
    for (var i = 0; i < count; i++) {
      final x = left + (i * dayStep);
      canvas.drawLine(
        Offset(x, top + 2),
        Offset(x, bottom),
        Paint()
          ..color = const Color(0xFFB7CFCC).withValues(alpha: 0.12)
          ..strokeWidth = 1,
      );
      final day = series.first.points[i].day;
      final label =
          '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: Color(0xFF5A7573),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = (x - (tp.width / 2)).clamp(left, right - tp.width);
      tp.paint(canvas, Offset(dx, bottom + 4));
    }
    for (final line in series) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = line.color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      for (var i = 0; i < line.points.length; i++) {
        final x = left + (i * dayStep);
        final y = bottom - ((line.points[i].value / maxY) * h);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, stroke);
      for (var i = 0; i < line.points.length; i++) {
        final x = left + (i * dayStep);
        final y = bottom - ((line.points[i].value / maxY) * h);
        canvas.drawCircle(Offset(x, y), 3.4, Paint()..color = line.color);
        canvas.drawCircle(
          Offset(x, y),
          1.2,
          Paint()..color = Colors.white.withValues(alpha: 0.92),
        );
      }
    }
    canvas.drawLine(
      Offset(left, bottom),
      Offset(right, bottom),
      Paint()
        ..color = const Color(0xFFB7CFCC).withValues(alpha: 0.70)
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _DirectionMaterialLineChartPainter oldDelegate) {
    return oldDelegate.series != series || oldDelegate.maxY != maxY;
  }
}

class _DirectionLineChartYAxisPainter extends CustomPainter {
  final double maxY;
  final double topPad;
  final double bottomPad;

  const _DirectionLineChartYAxisPainter({
    required this.maxY,
    required this.topPad,
    required this.bottomPad,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const yTicks = 5;
    final axisColor = const Color(0xFFB7CFCC);
    final left = size.width - 1.0;
    final top = topPad;
    final bottom = size.height - bottomPad;
    final h = math.max(1.0, bottom - top);
    for (var i = 0; i < yTicks; i++) {
      final ratio = i / (yTicks - 1);
      final y = bottom - (h * ratio);
      canvas.drawLine(
        Offset(left - 6, y),
        Offset(left, y),
        Paint()
          ..color = axisColor.withValues(alpha: 0.70)
          ..strokeWidth = 1,
      );
      final value = maxY * ratio;
      final label = value >= 1000
          ? '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}t'
          : formatDecimal(value, decimals: 0);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Color(0xFF9EB8B5),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 10);
      tp.paint(canvas, Offset(size.width - tp.width - 8, y - (tp.height / 2)));
    }
    canvas.drawLine(
      Offset(left, top),
      Offset(left, bottom),
      Paint()
        ..color = axisColor.withValues(alpha: 0.74)
        ..strokeWidth = 1.1,
    );
  }

  @override
  bool shouldRepaint(covariant _DirectionLineChartYAxisPainter oldDelegate) {
    return oldDelegate.maxY != maxY;
  }
}

class _DirectionMaterialFlowBundle {
  final List<_DirectionMaterialLineSeries> entrySeries;
  final List<_DirectionMaterialLineSeries> exitSeries;
  final List<_DirectionMaterialAverageRow> entryWeeklyAverages;
  final List<_DirectionMaterialAverageRow> exitWeeklyAverages;
  final int entryRowCount;
  final int exitRowCount;
  final double entryTotalKg;
  final double exitTotalKg;

  const _DirectionMaterialFlowBundle({
    required this.entrySeries,
    required this.exitSeries,
    required this.entryWeeklyAverages,
    required this.exitWeeklyAverages,
    required this.entryRowCount,
    required this.exitRowCount,
    required this.entryTotalKg,
    required this.exitTotalKg,
  });
}

class _DirectionMaterialLineSeries {
  final String label;
  final Color color;
  final List<_DirectionMaterialLinePoint> points;

  const _DirectionMaterialLineSeries({
    required this.label,
    required this.color,
    required this.points,
  });
}

class _DirectionMaterialLinePoint {
  final DateTime day;
  final double value;

  const _DirectionMaterialLinePoint({required this.day, required this.value});
}

class _DirectionMaterialAverageRow {
  final String label;
  final double averageKgPerDay;
  final Color color;

  const _DirectionMaterialAverageRow({
    required this.label,
    required this.averageKgPerDay,
    required this.color,
  });
}

class _DirectionHoveredPointInfo {
  final int dayIndex;
  final int seriesIndex;
  final String label;
  final Color color;
  final double value;
  final String dayLabel;

  const _DirectionHoveredPointInfo({
    required this.dayIndex,
    required this.seriesIndex,
    required this.label,
    required this.color,
    required this.value,
    required this.dayLabel,
  });

  String get key => '$dayIndex|$seriesIndex|$value';
}

_DirectionMaterialFlowBundle _buildDirectionMaterialFlowBundle({
  required List<Map<String, dynamic>> inRows,
  required List<Map<String, dynamic>> outRows,
  required DateTime startDate,
  required DateTime endDate,
}) {
  final labels = <String, String>{};
  final palette = <String, Color>{};
  final entryByMaterial = <String, Map<String, double>>{};
  final exitByMaterial = <String, Map<String, double>>{};
  for (final row in inRows) {
    final day = _directionDbDate(
      DateUtils.dateOnly(DateTime.parse(row['op_date'].toString())),
    );
    final code = (row['material'] ?? '').toString().trim();
    final label = (row['material_label'] ?? code).toString().trim();
    if (code.isEmpty) continue;
    labels[code] = label.isEmpty ? code : label;
    palette.putIfAbsent(code, () => _directionMaterialColor(code));
    final kg = _directionEffectiveKgFromRow(row);
    entryByMaterial.putIfAbsent(code, () => <String, double>{});
    entryByMaterial[code]![day] = (entryByMaterial[code]![day] ?? 0) + kg;
  }
  for (final row in outRows) {
    final day = _directionDbDate(
      DateUtils.dateOnly(DateTime.parse(row['op_date'].toString())),
    );
    final code = (row['material'] ?? '').toString().trim();
    final label = (row['material_label'] ?? code).toString().trim();
    if (code.isEmpty) continue;
    labels[code] = label.isEmpty ? code : label;
    palette.putIfAbsent(code, () => _directionMaterialColor(code));
    final kg = _directionEffectiveKgFromRow(row);
    exitByMaterial.putIfAbsent(code, () => <String, double>{});
    exitByMaterial[code]![day] = (exitByMaterial[code]![day] ?? 0) + kg;
  }
  final days = <DateTime>[];
  for (
    DateTime cursor = startDate;
    !cursor.isAfter(endDate);
    cursor = cursor.add(const Duration(days: 1))
  ) {
    days.add(cursor);
  }
  final entrySeries =
      entryByMaterial.entries
          .map(
            (entry) => _DirectionMaterialLineSeries(
              label: labels[entry.key] ?? entry.key,
              color: palette[entry.key] ?? _directionMaterialColor(entry.key),
              points: days
                  .map((day) {
                    final key = _directionDbDate(day);
                    return _DirectionMaterialLinePoint(
                      day: day,
                      value: entry.value[key] ?? 0,
                    );
                  })
                  .toList(growable: false),
            ),
          )
          .toList(growable: false)
        ..sort(_directionSeriesSorter);
  final exitSeries =
      exitByMaterial.entries
          .map(
            (entry) => _DirectionMaterialLineSeries(
              label: labels[entry.key] ?? entry.key,
              color: palette[entry.key] ?? _directionMaterialColor(entry.key),
              points: days
                  .map((day) {
                    final key = _directionDbDate(day);
                    return _DirectionMaterialLinePoint(
                      day: day,
                      value: entry.value[key] ?? 0,
                    );
                  })
                  .toList(growable: false),
            ),
          )
          .toList(growable: false)
        ..sort(_directionSeriesSorter);
  final weekStart = _directionWeekStart(DateUtils.dateOnly(DateTime.now()));
  final elapsedDays =
      DateUtils.dateOnly(DateTime.now()).difference(weekStart).inDays + 1;
  final entryWeeklyAverages =
      entrySeries
          .map(
            (series) => _DirectionMaterialAverageRow(
              label: series.label,
              averageKgPerDay:
                  series.points
                      .where((point) => !point.day.isBefore(weekStart))
                      .fold<double>(0, (sum, point) => sum + point.value) /
                  elapsedDays,
              color: series.color,
            ),
          )
          .where((row) => row.averageKgPerDay > 0.009)
          .toList(growable: false)
        ..sort((a, b) => b.averageKgPerDay.compareTo(a.averageKgPerDay));
  final exitWeeklyAverages =
      exitSeries
          .map(
            (series) => _DirectionMaterialAverageRow(
              label: series.label,
              averageKgPerDay:
                  series.points
                      .where((point) => !point.day.isBefore(weekStart))
                      .fold<double>(0, (sum, point) => sum + point.value) /
                  elapsedDays,
              color: series.color,
            ),
          )
          .where((row) => row.averageKgPerDay > 0.009)
          .toList(growable: false)
        ..sort((a, b) => b.averageKgPerDay.compareTo(a.averageKgPerDay));
  return _DirectionMaterialFlowBundle(
    entrySeries: entrySeries,
    exitSeries: exitSeries,
    entryWeeklyAverages: entryWeeklyAverages.take(8).toList(growable: false),
    exitWeeklyAverages: exitWeeklyAverages.take(8).toList(growable: false),
    entryRowCount: inRows.length,
    exitRowCount: outRows.length,
    entryTotalKg: inRows.fold<double>(
      0,
      (sum, row) => sum + _directionEffectiveKgFromRow(row),
    ),
    exitTotalKg: outRows.fold<double>(
      0,
      (sum, row) => sum + _directionEffectiveKgFromRow(row),
    ),
  );
}

List<Map<String, dynamic>> _normalizeDirectionMovementRows({
  required List<Map<String, dynamic>> rows,
  required bool isIn,
}) {
  return rows
      .map((row) {
        final general = (row['general_material'] as Map?)
            ?.cast<String, dynamic>();
        final commercial = (row['commercial_material'] as Map?)
            ?.cast<String, dynamic>();
        final sourceCommercial = (row['source_commercial'] as Map?)
            ?.cast<String, dynamic>();
        final commercialGeneral = (commercial?['general_material'] as Map?)
            ?.cast<String, dynamic>();
        final sourceCommercialGeneral =
            (sourceCommercial?['general_material'] as Map?)
                ?.cast<String, dynamic>();
        final materialCode = isIn
            ? (general?['code'] ??
                  sourceCommercialGeneral?['code'] ??
                  sourceCommercial?['code'])
            : (commercialGeneral?['code'] ??
                  commercial?['code'] ??
                  general?['code']);
        final materialLabel = isIn
            ? (general?['name'] ??
                  sourceCommercialGeneral?['name'] ??
                  sourceCommercial?['name'])
            : (commercialGeneral?['name'] ??
                  commercial?['name'] ??
                  general?['name']);
        return <String, dynamic>{
          ...row,
          'material_id': isIn
              ? row['general_material_id']
              : (commercial == null ? null : commercial['general_material_id']),
          'material': materialCode,
          'material_label': materialLabel ?? materialCode,
          'commercial_material_code': isIn
              ? (sourceCommercial == null ? null : sourceCommercial['code'])
              : (commercial == null ? null : commercial['code']),
          'net_kg': row['net_kg'] ?? row['weight_kg'],
          'movement_origin': 'MANUAL',
        };
      })
      .toList(growable: false);
}

int _directionSeriesSorter(
  _DirectionMaterialLineSeries a,
  _DirectionMaterialLineSeries b,
) {
  final aTotal = a.points.fold<double>(0, (sum, point) => sum + point.value);
  final bTotal = b.points.fold<double>(0, (sum, point) => sum + point.value);
  return bTotal.compareTo(aTotal);
}

double _directionLineChartMaxY(List<_DirectionMaterialLineSeries> series) {
  final values = <double>[
    for (final line in series) ...line.points.map((point) => point.value),
  ];
  if (values.isEmpty) return 1;
  return math.max(1.0, values.reduce(math.max) * 1.10);
}

double _directionEffectiveKgFromRow(Map<String, dynamic> row) {
  final direct =
      _directionToDouble(row['net_kg']) ?? _directionToDouble(row['weight_kg']);
  if (direct != null && direct > 0) return direct;
  final gross = _directionToDouble(row['gross_kg']);
  final tare = _directionToDouble(row['tare_kg']) ?? 0;
  if (gross != null && gross > 0) {
    return math.max(0, gross - (tare < 0 ? 0 : tare)).toDouble();
  }
  final adjusted = _directionToDouble(row['total_amount_kg']);
  if (adjusted != null && adjusted > 0) return adjusted;
  return 0;
}

double? _directionToDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  final compact = text.replaceAll(RegExp(r'[^0-9,.\-]'), '');
  if (compact.isEmpty) return null;
  final normalized = compact.contains(',') && compact.contains('.')
      ? compact.replaceAll(',', '')
      : compact.replaceAll(',', '.');
  return double.tryParse(normalized);
}

DateTime _directionWeekStart(DateTime date) =>
    date.subtract(Duration(days: date.weekday - 1));

String _directionDbDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

Color _directionMaterialColor(String key) {
  const palette = <Color>[
    Color(0xFF8BE28B),
    Color(0xFFFFC16D),
    Color(0xFF6FD0FF),
    Color(0xFFFF8EA1),
    Color(0xFF9E8CFF),
    Color(0xFF5FE0C5),
    Color(0xFFFFD36B),
    Color(0xFFC7F07A),
  ];
  final hash = key.codeUnits.fold<int>(0, (sum, code) => sum + code);
  return palette[hash % palette.length];
}

class _DirectionGerenciaDashboardSummary extends StatefulWidget {
  final Future<void> Function() onOpenGerencia;

  const _DirectionGerenciaDashboardSummary({required this.onOpenGerencia});

  @override
  State<_DirectionGerenciaDashboardSummary> createState() =>
      _DirectionGerenciaDashboardSummaryState();
}

class _DirectionGerenciaDashboardSummaryState
    extends State<_DirectionGerenciaDashboardSummary> {
  GerenciaBaleWeeklyTrackingBundle? _bundle;
  bool _loading = true;
  bool _hovering = false;
  bool _refreshing = false;
  bool _pendingReload = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _requestReload(showLoader: true);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 90),
      (_) => _requestReload(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _requestReload({bool showLoader = false}) {
    if (!mounted) return;
    if (_refreshing) {
      _pendingReload = true;
      return;
    }
    unawaited(_load(silent: !showLoader));
  }

  Future<void> _load({bool silent = false}) async {
    if (_refreshing) {
      _pendingReload = true;
      return;
    }
    _refreshing = true;
    if (!silent && mounted) {
      setState(() => _loading = true);
    }
    try {
      final bundle = await GerenciaBaleWeeklyTrackingStore.loadCurrentWeek();
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    } finally {
      _refreshing = false;
      if (_pendingReload && mounted) {
        _pendingReload = false;
        unawaited(_load(silent: true));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bundle = _bundle;
    final productionActual = bundle?.totalProductionActual ?? 0;
    final productionTarget = bundle?.currentPlan?.totalProductionTarget ?? 0;
    final shipmentActual = bundle?.totalShipmentActual ?? 0;
    final shipmentTarget = bundle?.currentPlan?.totalShipmentTarget ?? 0;
    final productionRatio = productionTarget <= 0
        ? 0.0
        : (productionActual / productionTarget).clamp(0.0, 1.0);
    final shipmentRatio = shipmentTarget <= 0
        ? 0.0
        : (shipmentActual / shipmentTarget).clamp(0.0, 1.0);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        offset: _hovering ? const Offset(0, -0.014) : Offset.zero,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          scale: _hovering ? 1.01 : 1.0,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () async => widget.onOpenGerencia(),
              child: _DirectionGlassPanel(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                borderRadius: BorderRadius.circular(28),
                blurSigma: 30,
                fillColor: kDirectionOliveDeep.withValues(alpha: 0.24),
                borderColor: Colors.white.withValues(
                  alpha: _hovering ? 0.34 : 0.28,
                ),
                shadowColor: Colors.black.withValues(
                  alpha: _hovering ? 0.18 : 0.14,
                ),
                edgeHighlightColor: Colors.white.withValues(
                  alpha: _hovering ? 0.78 : 0.70,
                ),
                bevelShadowColor: Colors.black.withValues(alpha: 0.14),
                glowColor: kDirectionOliveGlow.withValues(
                  alpha: _hovering ? 0.18 : 0.12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            bundle == null
                                ? 'Semana actual'
                                : _directionGerenciaWeekLabel(bundle),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Icon(
                          Icons.north_east_rounded,
                          color: Colors.white.withValues(alpha: 0.78),
                          size: 28,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (_loading && bundle == null)
                      const SizedBox(
                        height: 142,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (bundle == null)
                      const SizedBox(
                        height: 142,
                        child: Center(
                          child: Text(
                            'No fue posible cargar la semana actual de Gerencia.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: kDirectionMutedText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          _DirectionGerenciaWeeklyProgressRow(
                            label: 'Producción',
                            actual: productionActual,
                            target: productionTarget,
                            ratio: productionRatio,
                            accent: const Color(0xFFFF8E9B),
                          ),
                          const SizedBox(height: 18),
                          _DirectionGerenciaWeeklyProgressRow(
                            label: 'Embarque',
                            actual: shipmentActual,
                            target: shipmentTarget,
                            ratio: shipmentRatio,
                            accent: const Color(0xFFFFC07A),
                          ),
                        ],
                      ),
                    if (bundle != null && !bundle.hasPlan) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Todavía no hay meta semanal capturada; las barras muestran solo avance real acumulado.',
                        style: const TextStyle(
                          color: kDirectionMutedText,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectionGerenciaWeeklyProgressRow extends StatelessWidget {
  final String label;
  final int actual;
  final int target;
  final double ratio;
  final Color accent;

  const _DirectionGerenciaWeeklyProgressRow({
    required this.label,
    required this.actual,
    required this.target,
    required this.ratio,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final safeRatio = ratio.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$label · ${formatDecimal(actual, decimals: 0)} / ${formatDecimal(target, decimals: 0)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
            Text(
              '${(safeRatio * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 16,
            color: Colors.white.withValues(alpha: 0.08),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: safeRatio,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent, accent.withValues(alpha: 0.68)],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _directionGerenciaWeekLabel(GerenciaBaleWeeklyTrackingBundle bundle) {
  final start = bundle.weekStartDate;
  final end = bundle.weekEndDate;
  final weekNumber = _directionGerenciaIsoWeekNumber(start);
  return 'Semana $weekNumber · ${_directionGerenciaShortDate(start)} - ${_directionGerenciaShortDate(end)}';
}

String _directionGerenciaShortDate(DateTime value) {
  return '${value.day} ${_monthShortLabel(DateTime(value.year, value.month))}'
      .toLowerCase();
}

int _directionGerenciaIsoWeekNumber(DateTime value) {
  final normalized = DateTime(value.year, value.month, value.day);
  final shifted = normalized.add(Duration(days: 4 - normalized.weekday));
  final yearStart = DateTime(shifted.year, 1, 1);
  return ((shifted.difference(yearStart).inDays) / 7).floor() + 1;
}

class _DirectionOperationalServicesSummary extends StatefulWidget {
  final Future<void> Function() onOpenOperationalDashboard;

  const _DirectionOperationalServicesSummary({
    required this.onOpenOperationalDashboard,
  });

  @override
  State<_DirectionOperationalServicesSummary> createState() =>
      _DirectionOperationalServicesSummaryState();
}

class _DirectionOperationalServicesSummaryState
    extends State<_DirectionOperationalServicesSummary>
    with WidgetsBindingObserver {
  final SupabaseClient _supa = Supabase.instance.client;
  bool _loadingDates = true;
  bool _loadingRows = true;
  bool _hovering = false;
  bool _refreshing = false;
  bool _pendingReload = false;
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  List<DateTime> _datesWithServices = <DateTime>[];
  List<_DirectionServiceSummaryItem> _items = <_DirectionServiceSummaryItem>[];
  Timer? _autoRefreshTimer;
  RealtimeChannel? _servicesRealtimeChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_reload(showLoader: true));
    _setupAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _servicesRealtimeChannel?.unsubscribe();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _requestReload();
    }
  }

  void _setupAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _requestReload();
    });

    _servicesRealtimeChannel?.unsubscribe();
    _servicesRealtimeChannel = _supa
        .channel('direction-dashboard-services-summary')
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
      if (mounted && _pendingReload) {
        _pendingReload = false;
        _requestReload();
      }
    }
  }

  DateTime _parseDate(dynamic value) {
    if (value is String && value.length >= 10) {
      final year = int.tryParse(value.substring(0, 4));
      final month = int.tryParse(value.substring(5, 7));
      final day = int.tryParse(value.substring(8, 10));
      if (year != null && month != null && day != null) {
        return DateTime(year, month, day);
      }
    }
    return DateUtils.dateOnly(DateTime.now());
  }

  String _formatDbDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _formatStatus(String raw) {
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _formatDateEs(DateTime value) {
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

      final dates = <DateTime>{};
      for (final row in (data as List)) {
        final value = (row as Map<String, dynamic>)['due_date'];
        if (value == null) continue;
        dates.add(DateUtils.dateOnly(_parseDate(value)));
      }

      final sorted = dates.toList()..sort();
      if (!mounted) return;
      setState(() {
        _datesWithServices = sorted;
        if (showLoader) _loadingDates = false;
      });
    } catch (e, st) {
      AppErrorReporter.report(
        e,
        st,
        fallbackMessage: 'No se pudieron cargar las fechas de servicios.',
      );
      if (!mounted) return;
      setState(() {
        _datesWithServices = const [];
        if (showLoader) _loadingDates = false;
      });
    }
  }

  Future<void> _loadRowsForSelectedDate({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => _loadingRows = true);
    }
    final data = await _supa
        .from('v_services_grid')
        .select('*')
        .eq('due_date', _formatDbDate(_selectedDate))
        .order('created_at');

    final rows = (data as List).cast<Map<String, dynamic>>();
    final mapped = rows
        .map((row) {
          final company =
              ((row['client_name'] ?? row['client_label'] ?? 'SIN EMPRESA')
                      as String)
                  .trim();
          final operator =
              ((row['driver_name'] ??
                          row['driver_full_name'] ??
                          row['driver_employee_name'] ??
                          'SIN OPERADOR')
                      as String)
                  .trim();
          final status = _formatStatus(
            ((row['status'] ?? '') as String).trim(),
          );
          return _DirectionServiceSummaryItem(
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
  }

  DateTime? get _prevDate {
    final previous =
        _datesWithServices
            .where((date) => date.isBefore(_selectedDate))
            .toList()
          ..sort();
    return previous.isEmpty ? null : previous.last;
  }

  DateTime? get _nextDate {
    final next =
        _datesWithServices.where((date) => date.isAfter(_selectedDate)).toList()
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
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        offset: _hovering ? const Offset(0, -0.014) : Offset.zero,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          scale: _hovering ? 1.01 : 1.0,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () async => widget.onOpenOperationalDashboard(),
              child: _DirectionGlassPanel(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                borderRadius: BorderRadius.circular(28),
                blurSigma: 30,
                fillColor: kDirectionOliveDeep.withValues(alpha: 0.24),
                borderColor: Colors.white.withValues(
                  alpha: _hovering ? 0.34 : 0.28,
                ),
                shadowColor: Colors.black.withValues(
                  alpha: _hovering ? 0.18 : 0.14,
                ),
                edgeHighlightColor: Colors.white.withValues(
                  alpha: _hovering ? 0.78 : 0.70,
                ),
                bevelShadowColor: Colors.black.withValues(alpha: 0.14),
                glowColor: kDirectionOliveGlow.withValues(
                  alpha: _hovering ? 0.18 : 0.12,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _DirectionDateNavButton(
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
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDateEs(_selectedDate),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: kDirectionSurfaceText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_items.length} servicio${_items.length == 1 ? '' : 's'}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: kDirectionMutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _DirectionDateNavButton(
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
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              'EMPRESA',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'OPERADOR',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'ESTADO',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : _items.isEmpty
                          ? const Center(
                              child: Text(
                                'No hay servicios para la fecha seleccionada.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: kDirectionMutedText,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                Expanded(
                                  child: ListView.separated(
                                    physics: const ClampingScrollPhysics(),
                                    padding: EdgeInsets.zero,
                                    itemCount: _items.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) =>
                                        _DirectionServiceSummaryRow(
                                          item: _items[index],
                                        ),
                                  ),
                                ),
                                if (_items.length > 4) ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Desliza para ver más servicios.',
                                    style: TextStyle(
                                      color: kDirectionMutedText,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectionDateNavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _DirectionDateNavButton({
    required this.icon,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !enabled,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1.0 : 0.34,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              width: 38,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectionServiceSummaryItem {
  final String company;
  final String operator;
  final String status;

  const _DirectionServiceSummaryItem({
    required this.company,
    required this.operator,
    required this.status,
  });
}

class _DirectionServiceSummaryRow extends StatelessWidget {
  final _DirectionServiceSummaryItem item;

  const _DirectionServiceSummaryRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              item.company,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(
              item.operator,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kDirectionSurfaceText,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionCommercialFollowUpsSummary extends StatefulWidget {
  final Future<void> Function() onOpenCommercial;

  const _DirectionCommercialFollowUpsSummary({required this.onOpenCommercial});

  @override
  State<_DirectionCommercialFollowUpsSummary> createState() =>
      _DirectionCommercialFollowUpsSummaryState();
}

class _DirectionCommercialFollowUpsSummaryState
    extends State<_DirectionCommercialFollowUpsSummary> {
  List<CommercialWeeklyFollowUpSummaryRecord>? _weeklyRows;
  bool _loading = true;
  bool _hovering = false;
  bool _refreshing = false;
  bool _pendingReload = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _requestReload(showLoader: true);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 90),
      (_) => _requestReload(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _requestReload({bool showLoader = false}) {
    if (!mounted) return;
    if (_refreshing) {
      _pendingReload = true;
      return;
    }
    unawaited(_load(silent: !showLoader));
  }

  Future<void> _load({bool silent = false}) async {
    if (_refreshing) {
      _pendingReload = true;
      return;
    }
    _refreshing = true;
    if (!silent && mounted) {
      setState(() => _loading = true);
    }
    try {
      final currentWeek = _directionCurrentWeekRange(DateTime.now());
      final bundle = await CommercialStore.loadWeeklyFollowUpSummary(
        weekStart: currentWeek.$1,
        weekEnd: currentWeek.$2,
      );
      if (!mounted) return;
      setState(() {
        _weeklyRows = bundle;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    } finally {
      _refreshing = false;
      if (_pendingReload && mounted) {
        _pendingReload = false;
        unawaited(_load(silent: true));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentWeek = _directionCurrentWeekRange(DateTime.now());
    final rows = _weeklyRows == null
        ? const <_DirectionCommercialFollowUpRowData>[]
        : _weeklyRows!
              .map(
                (entry) => _DirectionCommercialFollowUpRowData(
                  accountName: entry.accountName,
                  interactionType: entry.interactionType,
                  status: entry.status,
                  date: entry.referenceDate,
                ),
              )
              .toList(growable: false);
    final visibleRows = rows.take(4).toList(growable: false);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        offset: _hovering ? const Offset(0, -0.014) : Offset.zero,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          scale: _hovering ? 1.01 : 1.0,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () async => widget.onOpenCommercial(),
              child: _DirectionGlassPanel(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                borderRadius: BorderRadius.circular(28),
                blurSigma: 30,
                fillColor: kDirectionOliveDeep.withValues(alpha: 0.24),
                borderColor: Colors.white.withValues(
                  alpha: _hovering ? 0.34 : 0.28,
                ),
                shadowColor: Colors.black.withValues(
                  alpha: _hovering ? 0.18 : 0.14,
                ),
                edgeHighlightColor: Colors.white.withValues(
                  alpha: _hovering ? 0.78 : 0.70,
                ),
                bevelShadowColor: Colors.black.withValues(alpha: 0.14),
                glowColor: kDirectionOliveGlow.withValues(
                  alpha: _hovering ? 0.18 : 0.12,
                ),
                child: SizedBox(
                  height: 356,
                  child: Column(
                    children: [
                      const Text(
                        'Seguimientos de la Semana',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _directionWeekLabel(currentWeek.$1, currentWeek.$2),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kDirectionSurfaceText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${rows.length} seguimiento${rows.length == 1 ? '' : 's'}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: kDirectionMutedText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                'CUENTA',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'TIPO',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'FECHA',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'ESTADO',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _loading && _weeklyRows == null
                            ? const Center(child: CircularProgressIndicator())
                            : visibleRows.isEmpty
                            ? const Center(
                                child: Text(
                                  'No hay seguimientos registrados para esta semana.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: kDirectionMutedText,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : Column(
                                children: [
                                  for (final row in visibleRows) ...[
                                    _DirectionCommercialFollowUpSummaryRow(
                                      row: row,
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  const Spacer(),
                                  if (rows.length > visibleRows.length)
                                    Text(
                                      '+${rows.length - visibleRows.length} más en Desarrollo Comercial',
                                      style: const TextStyle(
                                        color: kDirectionMutedText,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ],
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

class _DirectionCommercialFollowUpRowData {
  final String accountName;
  final String interactionType;
  final String status;
  final DateTime date;

  const _DirectionCommercialFollowUpRowData({
    required this.accountName,
    required this.interactionType,
    required this.status,
    required this.date,
  });
}

(DateTime, DateTime) _directionCurrentWeekRange(DateTime value) {
  final normalized = DateUtils.dateOnly(value);
  final start = normalized.subtract(Duration(days: normalized.weekday - 1));
  final end = start.add(const Duration(days: 6));
  return (start, end);
}

String _directionWeekLabel(DateTime start, DateTime end) {
  return '${start.day} ${_monthShortLabel(start).toLowerCase()} - ${end.day} ${_monthShortLabel(end).toLowerCase()}';
}

String _directionCompactDateLabel(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month';
}

String _directionCommercialPrettyLabel(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return 'Sin dato';
  return normalized
      .replaceAll('_', ' ')
      .split(' ')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}

class _DirectionCommercialFollowUpSummaryRow extends StatelessWidget {
  final _DirectionCommercialFollowUpRowData row;

  const _DirectionCommercialFollowUpSummaryRow({required this.row});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              row.accountName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              _directionCommercialPrettyLabel(row.interactionType),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: kDirectionSurfaceText,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              _directionCompactDateLabel(row.date),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _directionCommercialPrettyLabel(row.status),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionMaintenanceEntryCard extends StatefulWidget {
  final Future<void> Function() onTap;

  const _DirectionMaintenanceEntryCard({required this.onTap});

  @override
  State<_DirectionMaintenanceEntryCard> createState() =>
      _DirectionMaintenanceEntryCardState();
}

class _DirectionMaintenanceEntryCardState
    extends State<_DirectionMaintenanceEntryCard> {
  late final Future<DirectionMaintenanceSummary> _summary =
      DirectionOperationsRepository().loadMaintenanceSummary();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DirectionMaintenanceSummary>(
      future: _summary,
      builder: (context, snapshot) {
        final summary = snapshot.data;
        final badge = summary == null
            ? 'Cargando...'
            : summary.criticalCount > 0
            ? '${summary.criticalCount} críticas'
            : summary.openCount > 0
            ? '${summary.openCount} abiertas'
            : 'Sin alertas';
        final subtitle = summary == null
            ? 'Seguimiento ejecutivo de órdenes de trabajo.'
            : summary.openCount == 0
            ? 'No hay OT abiertas por seguir.'
            : '${summary.staleCount} sin movimiento · ${summary.waitingDirectionCount} en cotización';
        return _DirectionAnalysisEntryCard(
          title: 'Mantenimiento OT',
          subtitle: subtitle,
          badge: badge,
          icon: Icons.build_circle_outlined,
          onTap: widget.onTap,
        );
      },
    );
  }
}

class _DirectionAnalysisEntryCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final Future<void> Function() onTap;

  const _DirectionAnalysisEntryCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_DirectionAnalysisEntryCard> createState() =>
      _DirectionAnalysisEntryCardState();
}

class _DirectionAnalysisEntryCardState
    extends State<_DirectionAnalysisEntryCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    const badgeAccent = kDirectionOliveMist;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        offset: _hovering ? const Offset(0, -0.014) : Offset.zero,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          scale: _hovering ? 1.01 : 1.0,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _DirectionGlassPanel(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                borderRadius: BorderRadius.circular(26),
                blurSigma: 30,
                fillColor: kDirectionOliveDeep.withValues(alpha: 0.24),
                borderColor: Colors.white.withValues(alpha: 0.26),
                shadowColor: Colors.black.withValues(alpha: 0.10),
                edgeHighlightColor: Colors.white.withValues(alpha: 0.66),
                bevelShadowColor: Colors.black.withValues(alpha: 0.16),
                glowColor: kDirectionOliveGlow.withValues(
                  alpha: _hovering ? 0.16 : 0.10,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () async => widget.onTap(),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: kDirectionOliveGlow.withValues(alpha: 0.16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.24),
                            ),
                          ),
                          child: Icon(
                            widget.icon,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
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
                                  borderRadius: BorderRadius.circular(999),
                                  color: badgeAccent.withValues(alpha: 0.10),
                                  border: Border.all(
                                    color: badgeAccent.withValues(alpha: 0.34),
                                  ),
                                ),
                                child: Text(
                                  widget.badge,
                                  style: TextStyle(
                                    color: badgeAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.subtitle,
                                style: const TextStyle(
                                  color: Color(0xFFD0E4FF),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.arrow_outward_rounded,
                          color: Color(0xFF92E9FF),
                          size: 22,
                        ),
                      ],
                    ),
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

class _DirectionMoneyMetricsSection extends StatefulWidget {
  final Future<void> Function() onOpenVault;
  final Future<void> Function() onOpenMenudeoAnalysis;
  final Future<void> Function() onOpenFinanzasDashboard;

  const _DirectionMoneyMetricsSection({
    required this.onOpenVault,
    required this.onOpenMenudeoAnalysis,
    required this.onOpenFinanzasDashboard,
  });

  @override
  State<_DirectionMoneyMetricsSection> createState() =>
      _DirectionMoneyMetricsSectionState();
}

class _DirectionMoneyMetricsSectionState
    extends State<_DirectionMoneyMetricsSection> {
  late final Future<_DirectionMoneyMetricsSnapshot> _future = _loadSnapshot();

  Future<_DirectionMoneyMetricsSnapshot> _loadSnapshot() async {
    final results = await Future.wait<dynamic>([
      _loadDirectionVaultTotals(),
      _loadMenudeoCurrentCashSummary(),
      FinanzasBankAccountsStore.loadMovements(),
    ]);
    final vault = results[0] as ({double deposits, double expenses});
    final menudeo = results[1] as _DirectionMenudeoCashSummary;
    final bankMovements = results[2] as List<FinanzasBankMovementRecord>;
    return _DirectionMoneyMetricsSnapshot(
      vaultDeposits: vault.deposits,
      vaultExpenses: vault.expenses,
      menudeoCash: menudeo,
      bankMovements: bankMovements,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DirectionMoneyMetricsSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final cards = <Widget>[
          _DirectionMoneyMetricCard(
            title: 'TOTAL EN BÓVEDA',
            badge: 'Dirección',
            amount:
                (data?.vaultDeposits ?? _kDirectionVaultDeposits) -
                (data?.vaultExpenses ?? _kDirectionVaultExpenses),
            detail:
                'Entradas ${formatMoney(data?.vaultDeposits ?? _kDirectionVaultDeposits)} · '
                'Salidas ${formatMoney(data?.vaultExpenses ?? _kDirectionVaultExpenses)}',
            icon: Icons.account_balance_wallet_rounded,
            onTap: widget.onOpenVault,
          ),
          _DirectionMoneyMetricCard(
            title: 'EFECTIVO MENUDEO',
            badge: 'Canal menudeo',
            amount: data?.menudeoCash.totalCash ?? 0,
            detail:
                'Apertura ${formatMoney(data?.menudeoCash.openingCash ?? 0)} · '
                'Ventas ${formatMoney(data?.menudeoCash.sales ?? 0)} · '
                'Depósitos ${formatMoney(data?.menudeoCash.deposits ?? 0)}',
            icon: Icons.storefront_rounded,
            onTap: widget.onOpenMenudeoAnalysis,
          ),
          _DirectionMoneyMetricCard(
            title: 'CUENTA VH',
            badge: 'Celaya + Mazatlán',
            amount: data?.vhTotal ?? 0,
            detail:
                'Celaya ${formatMoney(data?.vhCelaya ?? 0)} · '
                'Mazatlán ${formatMoney(data?.vhMazatlan ?? 0)}',
            icon: Icons.account_balance_rounded,
            onTap: widget.onOpenFinanzasDashboard,
          ),
          _DirectionMoneyMetricCard(
            title: 'CUENTA DICSA',
            badge: 'Celaya + Mazatlán',
            amount: data?.dicsaTotal ?? 0,
            detail:
                'Celaya ${formatMoney(data?.dicsaCelaya ?? 0)} · '
                'Mazatlán ${formatMoney(data?.dicsaMazatlan ?? 0)}',
            icon: Icons.apartment_rounded,
            onTap: widget.onOpenFinanzasDashboard,
          ),
        ];

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: cards
              .map((card) => SizedBox(width: 292, child: card))
              .toList(growable: false),
        );
      },
    );
  }
}

class _DirectionMoneyMetricsSnapshot {
  final double vaultDeposits;
  final double vaultExpenses;
  final _DirectionMenudeoCashSummary menudeoCash;
  final List<FinanzasBankMovementRecord> bankMovements;

  const _DirectionMoneyMetricsSnapshot({
    required this.vaultDeposits,
    required this.vaultExpenses,
    required this.menudeoCash,
    required this.bankMovements,
  });

  double get vhCelaya => _sumBankBalance(company: 'VH', branch: 'CELAYA');
  double get vhMazatlan => _sumBankBalance(company: 'VH', branch: 'MAZATLAN');
  double get vhTotal => vhCelaya + vhMazatlan;

  double get dicsaCelaya => _sumBankBalance(company: 'DICSA', branch: 'CELAYA');
  double get dicsaMazatlan =>
      _sumBankBalance(company: 'DICSA', branch: 'MAZATLAN');
  double get dicsaTotal => dicsaCelaya + dicsaMazatlan;

  double _sumBankBalance({required String company, required String branch}) {
    return bankMovements
        .where(
          (row) =>
              row.company.trim().toUpperCase() == company &&
              row.branch.trim().toUpperCase() == branch,
        )
        .fold<double>(
          0,
          (sum, row) => sum + row.creditAmount - row.debitAmount,
        );
  }
}

class _DirectionMenudeoCashSummary {
  final double openingCash;
  final double sales;
  final double purchases;
  final double deposits;
  final double expenses;

  const _DirectionMenudeoCashSummary({
    required this.openingCash,
    required this.sales,
    required this.purchases,
    required this.deposits,
    required this.expenses,
  });

  double get totalCash => openingCash + sales + deposits - purchases - expenses;
}

class _DirectionMoneyMetricCard extends StatefulWidget {
  final String title;
  final String badge;
  final double amount;
  final String detail;
  final IconData icon;
  final Future<void> Function()? onTap;

  const _DirectionMoneyMetricCard({
    required this.title,
    required this.badge,
    required this.amount,
    required this.detail,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_DirectionMoneyMetricCard> createState() =>
      _DirectionMoneyMetricCardState();
}

class _DirectionMoneyMetricCardState extends State<_DirectionMoneyMetricCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        offset: _hovering ? const Offset(0, -0.018) : Offset.zero,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          scale: _hovering ? 1.012 : 1,
          child: _DirectionGlassPanel(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
            borderRadius: BorderRadius.circular(30),
            blurSigma: 32,
            fillColor: kDirectionOliveDeep.withValues(alpha: 0.22),
            borderColor: Colors.white.withValues(alpha: 0.32),
            shadowColor: Colors.black.withValues(
              alpha: _hovering ? 0.24 : 0.18,
            ),
            edgeHighlightColor: Colors.white.withValues(
              alpha: _hovering ? 0.86 : 0.78,
            ),
            bevelShadowColor: Colors.black.withValues(alpha: 0.14),
            glowColor: kDirectionOliveGlow.withValues(
              alpha: _hovering ? 0.22 : 0.14,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: widget.onTap == null
                    ? null
                    : () async => widget.onTap!(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.14),
                                kDirectionOliveMid.withValues(alpha: 0.72),
                              ],
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.icon,
                                size: 15,
                                color: kDirectionOliveGlow,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.badge,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                  color: kDirectionMutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.15,
                        color: kDirectionOliveGlow,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      formatMoney(widget.amount),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        height: 0.98,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kDirectionSurfaceText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectionVaultHeroCard extends StatefulWidget {
  final Future<void> Function() onTap;

  const _DirectionVaultHeroCard({required this.onTap});

  @override
  State<_DirectionVaultHeroCard> createState() =>
      _DirectionVaultHeroCardState();
}

Future<({double deposits, double expenses})> _loadDirectionVaultTotals() async {
  try {
    final vouchers = await DirectionVaultRepository.instance.loadVouchers();
    var deposits = 0.0;
    var expenses = 0.0;
    for (final voucher in vouchers) {
      if (voucher.type == 'deposit') {
        deposits += voucher.total;
      } else {
        expenses += voucher.total;
      }
    }
    return (deposits: deposits, expenses: expenses);
  } catch (_) {}
  return (
    deposits: _kDirectionVaultDeposits,
    expenses: _kDirectionVaultExpenses,
  );
}

Future<_DirectionMenudeoCashSummary> _loadMenudeoCurrentCashSummary() async {
  try {
    final openCutRows = await Supabase.instance.client
        .from('vw_men_cash_cuts_grid')
        .select('*')
        .isFilter('closed_at', null)
        .order('opened_at', ascending: false)
        .limit(1);
    final currentCutRows = (openCutRows as List).cast<Map<String, dynamic>>();
    final currentCut = currentCutRows.isEmpty ? null : currentCutRows.first;
    final currentCutId = currentCut?['id']?.toString();
    final openingCash =
        double.tryParse((currentCut?['opening_cash'] ?? '').toString()) ?? 0;
    if (currentCutId == null || currentCutId.trim().isEmpty) {
      return const _DirectionMenudeoCashSummary(
        openingCash: 0,
        sales: 0,
        purchases: 0,
        deposits: 0,
        expenses: 0,
      );
    }

    final results = await Future.wait<dynamic>([
      Supabase.instance.client
          .from('vw_men_tickets_grid')
          .select('amount_total,direction,status')
          .eq('cash_cut_id', currentCutId),
      Supabase.instance.client
          .from('vw_men_cash_vouchers_grid')
          .select('total_amount,voucher_type')
          .eq('cash_cut_id', currentCutId),
    ]);

    final ticketRows = (results[0] as List).cast<Map<String, dynamic>>();
    final voucherRows = (results[1] as List).cast<Map<String, dynamic>>();

    var sales = 0.0;
    var purchases = 0.0;
    var deposits = 0.0;
    var expenses = 0.0;

    for (final row in ticketRows) {
      final amount =
          double.tryParse((row['amount_total'] ?? '').toString()) ?? 0;
      final direction = (row['direction'] ?? '').toString();
      final status = (row['status'] ?? '').toString().toUpperCase();
      if (status != 'PAGADO') continue;
      if (direction == 'sale') {
        sales += amount;
      } else {
        purchases += amount;
      }
    }

    for (final row in voucherRows) {
      final amount =
          double.tryParse((row['total_amount'] ?? '').toString()) ?? 0;
      final type = (row['voucher_type'] ?? '').toString();
      if (type == 'deposit') {
        deposits += amount;
      } else if (type == 'expense') {
        expenses += amount;
      }
    }

    return _DirectionMenudeoCashSummary(
      openingCash: openingCash,
      sales: sales,
      purchases: purchases,
      deposits: deposits,
      expenses: expenses,
    );
  } catch (_) {
    return const _DirectionMenudeoCashSummary(
      openingCash: 0,
      sales: 0,
      purchases: 0,
      deposits: 0,
      expenses: 0,
    );
  }
}

class _DirectionVaultHeroCardState extends State<_DirectionVaultHeroCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({double deposits, double expenses})>(
      future: _loadDirectionVaultTotals(),
      builder: (context, snapshot) {
        final deposits = snapshot.data?.deposits ?? _kDirectionVaultDeposits;
        final expenses = snapshot.data?.expenses ?? _kDirectionVaultExpenses;
        final total = deposits - expenses;
        return MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            offset: _hovering ? const Offset(0, -0.018) : Offset.zero,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              scale: _hovering ? 1.012 : 1,
              child: _DirectionGlassPanel(
                padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
                borderRadius: BorderRadius.circular(34),
                blurSigma: 34,
                fillColor: kDirectionOliveDeep.withValues(alpha: 0.22),
                borderColor: Colors.white.withValues(alpha: 0.32),
                shadowColor: Colors.black.withValues(
                  alpha: _hovering ? 0.24 : 0.18,
                ),
                edgeHighlightColor: Colors.white.withValues(
                  alpha: _hovering ? 0.86 : 0.78,
                ),
                bevelShadowColor: Colors.black.withValues(alpha: 0.14),
                glowColor: kDirectionOliveGlow.withValues(
                  alpha: _hovering ? 0.22 : 0.14,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: () async => widget.onTap(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.14),
                                kDirectionOliveMid.withValues(alpha: 0.72),
                              ],
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.account_balance_wallet_rounded,
                                size: 16,
                                color: kDirectionOliveGlow,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'TOTAL DE BÓVEDA',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.3,
                                  color: kDirectionMutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          formatMoney(total),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            height: 0.94,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Entradas ${formatMoney(deposits)}  ·  Salidas ${formatMoney(expenses)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: kDirectionSurfaceText,
                          ),
                        ),
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

class _GeneralDashboardBrand extends StatelessWidget {
  final Animation<double> contentAnim;

  const _GeneralDashboardBrand({required this.contentAnim});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showTitle =
            constraints.maxWidth >= _kGeneralDashboardTitleMinWidth;
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DirectionGlassPanel(
                  padding: const EdgeInsets.all(0),
                  borderRadius: BorderRadius.circular(22),
                  blurSigma: 24,
                  fillColor: kDirectionOliveMist.withValues(alpha: 0.10),
                  borderColor: Colors.white.withValues(alpha: 0.34),
                  shadowColor: kDirectionOliveGlow.withValues(alpha: 0.08),
                  edgeHighlightColor: Colors.white.withValues(alpha: 0.72),
                  bevelShadowColor: Colors.black.withValues(alpha: 0.10),
                  glowColor: kDirectionOliveGlow.withValues(alpha: 0.10),
                  child: const SizedBox(
                    width: 72,
                    height: 72,
                    child: Center(child: DicsaLogoD(size: 52, progress: 1.0)),
                  ),
                ),
                if (showTitle) ...[
                  const SizedBox(width: 10),
                  Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Flexible(
                    child: Text(
                      'Dashboard Dirección',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.25,
                        height: 1.0,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GeneralHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final int notificationCount;

  const _GeneralHeaderButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.notificationCount = 0,
  });

  @override
  State<_GeneralHeaderButton> createState() => _GeneralHeaderButtonState();
}

class _GeneralHeaderButtonState extends State<_GeneralHeaderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final highlighted = enabled && _hovered;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: highlighted ? 1.03 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, highlighted ? -2 : 0, 0),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            splashColor: Colors.transparent,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
            onTap: enabled ? () => widget.onTap!() : null,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _DirectionGlassPanel(
                  width: 178,
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  borderRadius: BorderRadius.circular(16),
                  blurSigma: 26,
                  fillColor: enabled
                      ? kDirectionOliveMist.withValues(
                          alpha: highlighted ? 0.18 : 0.12,
                        )
                      : Colors.white.withValues(alpha: 0.05),
                  borderColor: enabled
                      ? Colors.white.withValues(
                          alpha: highlighted ? 0.54 : 0.34,
                        )
                      : Colors.white.withValues(alpha: 0.16),
                  shadowColor: highlighted
                      ? kDirectionOliveGlow.withValues(alpha: 0.14)
                      : Colors.black.withValues(alpha: 0.06),
                  edgeHighlightColor: Colors.white.withValues(alpha: 0.78),
                  bevelShadowColor: Colors.black.withValues(alpha: 0.12),
                  glowColor: highlighted
                      ? kDirectionOliveGlow.withValues(alpha: 0.18)
                      : kDirectionOliveSoft.withValues(alpha: 0.08),
                  child: Row(
                    children: [
                      Icon(widget.icon, size: 19, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ),
                ),
                if (widget.notificationCount > 0)
                  Positioned(
                    right: -6,
                    top: -8,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD92D20),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.92),
                          width: 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 12,
                            color: const Color(
                              0xFFD92D20,
                            ).withValues(alpha: 0.26),
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          widget.notificationCount > 9
                              ? '9+'
                              : '${widget.notificationCount}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
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

class _GeneralDashboardSideMenu extends StatelessWidget {
  final bool directionExpanded;
  final bool areasExpanded;
  final VoidCallback? onToggleDirectionExpanded;
  final VoidCallback? onToggleAreasExpanded;
  final Future<void> Function()? onOpenGeneralDashboard;
  final Future<void> Function()? onOpenDirectionCashWorkspace;
  final Future<void> Function()? onOpenDirectionCashCatalog;
  final Future<void> Function()? onOpenDirectionMenudeoAnalysis;
  final Future<void> Function()? onOpenDirectionTradeAnalysis;
  final Future<void> Function()? onOpenOperationalDashboard;
  final Future<void> Function()? onOpenMenudeo;
  final Future<void> Function()? onOpenMayoreo;
  final Future<void> Function()? onOpenCompras;
  final Future<void> Function()? onOpenFinanzas;
  final Future<void> Function()? onOpenContabilidad;
  final Future<void> Function()? onOpenLogistics;
  final Future<void> Function()? onOpenHumanResources;
  final Future<void> Function()? onOpenGerencia;
  final Future<void> Function()? onOpenCommercial;

  const _GeneralDashboardSideMenu({
    required this.directionExpanded,
    required this.areasExpanded,
    this.onToggleDirectionExpanded,
    this.onToggleAreasExpanded,
    this.onOpenGeneralDashboard,
    this.onOpenDirectionCashWorkspace,
    this.onOpenDirectionCashCatalog,
    this.onOpenDirectionMenudeoAnalysis,
    this.onOpenDirectionTradeAnalysis,
    this.onOpenOperationalDashboard,
    this.onOpenMenudeo,
    this.onOpenMayoreo,
    this.onOpenCompras,
    this.onOpenFinanzas,
    this.onOpenContabilidad,
    this.onOpenLogistics,
    this.onOpenHumanResources,
    this.onOpenGerencia,
    this.onOpenCommercial,
  });

  @override
  Widget build(BuildContext context) {
    return _DirectionGlassPanel(
      borderRadius: BorderRadius.circular(24),
      blurSigma: 30,
      fillColor: kDirectionOliveDeep.withValues(alpha: 0.34),
      borderColor: Colors.white.withValues(alpha: 0.34),
      shadowColor: kDirectionOliveGlow.withValues(alpha: 0.08),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.72),
      bevelShadowColor: Colors.black.withValues(alpha: 0.16),
      glowColor: kDirectionOliveGlow.withValues(alpha: 0.14),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Navegación Dirección',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Páginas de Dirección y áreas habilitadas',
                style: TextStyle(
                  color: kDirectionMutedText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 14),
                _MenuBlock(
                  icon: Icons.layers_rounded,
                  title: 'Dirección',
                  expanded: directionExpanded,
                  onToggle: onToggleDirectionExpanded,
                  children: [
                    _MenuActionItem(
                      icon: Icons.home_work_rounded,
                      title: 'Dashboard Dirección',
                      subtitle: 'Superficie ejecutiva principal',
                      current: true,
                      onTap: onOpenGeneralDashboard,
                    ),
                    const SizedBox(height: 8),
                    _MenuActionItem(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Bóveda',
                      subtitle: 'Captura operativa de efectivo',
                      onTap: onOpenDirectionCashWorkspace,
                    ),
                    const SizedBox(height: 8),
                    _MenuActionItem(
                      icon: Icons.tune_rounded,
                      title: 'Catálogo Bóveda',
                      subtitle: 'Conceptos, personas y parámetros',
                      onTap: onOpenDirectionCashCatalog,
                    ),
                    const SizedBox(height: 8),
                    _MenuActionItem(
                      icon: Icons.analytics_rounded,
                      title: 'Análisis Menudeo',
                      subtitle: 'Mercado, efectivo y operación',
                      onTap: onOpenDirectionMenudeoAnalysis,
                    ),
                    const SizedBox(height: 8),
                    _MenuActionItem(
                      icon: Icons.swap_horiz_rounded,
                      title: 'Compra-Venta',
                      subtitle: 'Consolidado ejecutivo por material general',
                      onTap: onOpenDirectionTradeAnalysis,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _MenuBlock(
                  icon: Icons.space_dashboard_rounded,
                  title: 'Áreas habilitadas',
                  expanded: areasExpanded,
                  onToggle: onToggleAreasExpanded,
                  children: [
                    _MenuActionItem(
                      icon: Icons.precision_manufacturing_rounded,
                      title: 'Operación',
                      subtitle: 'Dashboard operativo actual',
                      onTap: onOpenOperationalDashboard,
                    ),
                    const SizedBox(height: 8),
                    _MenuActionItem(
                      icon: Icons.storefront_rounded,
                      title: 'Menudeo',
                      subtitle: 'Dashboard comercial del área',
                      onTap: onOpenMenudeo,
                    ),
                    const SizedBox(height: 8),
                    _MenuActionItem(
                      icon: Icons.inventory_2_rounded,
                      title: 'Ventas Mayoreo',
                      subtitle: 'Preview activo del área',
                      onTap: onOpenMayoreo,
                    ),
                    const SizedBox(height: 8),
                    _MenuActionItem(
                      icon: Icons.shopping_cart_checkout_rounded,
                      title: 'Compras Mayoreo',
                      subtitle: 'Dashboard preliminar homologado',
                      onTap: onOpenCompras,
                    ),
                    const SizedBox(height: 8),
                    _MenuActionItem(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Finanzas',
                      subtitle: 'Centro preliminar de flujo y pagos',
                      onTap: onOpenFinanzas,
                    ),
                    const SizedBox(height: 8),
                    _MenuActionItem(
                      icon: Icons.local_shipping_rounded,
                      title: 'Logística',
                      subtitle: 'Dashboard inicial homologado',
                      onTap: onOpenLogistics,
                    ),
                    const SizedBox(height: 8),
                    _MenuActionItem(
                      icon: Icons.account_balance_rounded,
                      title: 'Contabilidad',
                      subtitle: 'Consolidado contable y estado de resultados',
                      onTap: onOpenContabilidad,
                    ),
                    const SizedBox(height: 8),
                    _MenuActionItem(
                      icon: Icons.monitor_heart_outlined,
                      title: 'Gerencia',
                      subtitle: 'Dashboard ejecutivo del area',
                      onTap: onOpenGerencia,
                    ),
                    const SizedBox(height: 8),
                    _MenuActionItem(
                      icon: Icons.badge_rounded,
                      title: 'Recursos Humanos',
                      subtitle: 'Dashboard inicial homologado',
                      onTap: onOpenHumanResources,
                    ),
                    const SizedBox(height: 8),
                    _MenuActionItem(
                      icon: Icons.radar_rounded,
                      title: 'Desarrollo Comercial',
                      subtitle: 'Radar y directorio comercial',
                      onTap: onOpenCommercial,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool expanded;
  final VoidCallback? onToggle;
  final List<Widget> children;

  const _MenuBlock({
    required this.icon,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return _DirectionGlassPanel(
      borderRadius: BorderRadius.circular(18),
      blurSigma: 22,
      fillColor: kDirectionOliveMid.withValues(alpha: 0.24),
      borderColor: Colors.white.withValues(alpha: 0.28),
      shadowColor: kDirectionOliveGlow.withValues(alpha: 0.06),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.66),
      bevelShadowColor: Colors.black.withValues(alpha: 0.14),
      glowColor: kDirectionOliveGlow.withValues(alpha: 0.10),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 160),
                    turns: expanded ? 0.25 : 0.0,
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: kDirectionSurfaceText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _MenuActionItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool current;
  final Future<void> Function()? onTap;

  const _MenuActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.current = false,
    required this.onTap,
  });

  @override
  State<_MenuActionItem> createState() => _MenuActionItemState();
}

class _MenuActionItemState extends State<_MenuActionItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final highlighted = enabled && (_hovered || widget.current);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? () => widget.onTap!() : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: highlighted
                ? kDirectionOliveMist.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.current
                  ? kDirectionGoldAccent.withValues(alpha: 0.34)
                  : Colors.white.withValues(alpha: 0.18),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: highlighted ? 0.16 : 0.08),
                kDirectionOliveGlow.withValues(
                  alpha: highlighted ? 0.10 : 0.04,
                ),
                kDirectionOliveDeep.withValues(alpha: 0.18),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: highlighted ? 18 : 8,
                offset: const Offset(0, 5),
                color: highlighted
                    ? kDirectionOliveGlow.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.05),
              ),
              BoxShadow(
                blurRadius: 8,
                offset: const Offset(-2, -2),
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 20, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kDirectionMutedText,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.current)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: kDirectionGoldAccent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectionGlassPanel extends StatelessWidget {
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
  final double? width;
  final double? height;

  const _DirectionGlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.blurSigma = 22,
    this.fillColor = const Color(0xC21B2009),
    this.borderColor = const Color(0x52FFFFFF),
    this.shadowColor = const Color(0x12000000),
    this.edgeHighlightColor = const Color(0xCCFFFFFF),
    this.bevelShadowColor = const Color(0x18000000),
    this.glowColor = const Color(0x30D8E38A),
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: borderRadius,
            border: Border.all(color: borderColor),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.10),
                kDirectionOliveGlow.withValues(alpha: 0.05),
                kDirectionOliveDeep.withValues(alpha: 0.24),
              ],
              stops: const [0.0, 0.38, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                offset: const Offset(0, 8),
                color: shadowColor,
              ),
              BoxShadow(
                blurRadius: 16,
                offset: const Offset(-3, -3),
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
                          kDirectionOliveGlow.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.22, 0.56],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                top: 8,
                height: ((height ?? 56) * 0.34).clamp(16.0, 40.0),
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.18),
                          Colors.white.withValues(alpha: 0.06),
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
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          bevelShadowColor.withValues(alpha: 0.16),
                        ],
                        stops: const [0.0, 0.72, 1.0],
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
                      gradient: RadialGradient(
                        center: const Alignment(-0.75, -0.85),
                        radius: 1.0,
                        colors: [
                          Colors.white.withValues(alpha: 0.12),
                          kDirectionOliveGlow.withValues(alpha: 0.03),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.18, 0.58],
                      ),
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
