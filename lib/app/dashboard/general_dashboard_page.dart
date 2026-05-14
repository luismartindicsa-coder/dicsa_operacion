import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_navigation.dart';
import '../direction/direction_cash_entries_exits_page.dart';
import '../direction/direction_cash_taxonomy_page.dart';
import '../direction/direction_maintenance_page.dart';
import '../direction/direction_menudeo_analysis_page.dart';
import '../direction/direction_operations_repository.dart';
import '../direction/direction_purchase_orders_page.dart';
import '../mayoreo/mayoreo_dashboard_preview_page.dart';
import '../menudeo/menudeo_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/utils/number_formatters.dart';
import 'dashboard_page.dart';

const double _kGeneralDashboardTitleMinWidth = 440;
const double _kDirectionVaultDeposits = 40350;
const double _kDirectionVaultExpenses = 8850;
const String _kDirectionVaultArea = 'direccion_boveda_vouchers';

class GeneralDashboardPage extends StatefulWidget {
  final bool instantOpen;

  const GeneralDashboardPage({super.key, this.instantOpen = false});

  @override
  State<GeneralDashboardPage> createState() => _GeneralDashboardPageState();
}

class _GeneralDashboardPageState extends State<GeneralDashboardPage> {
  bool _directionExpanded = true;
  bool _areasExpanded = true;
  bool _menuOverlayOpen = false;

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que deseas cerrar tu sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
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
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape && _menuOverlayOpen) {
          setState(() => _menuOverlayOpen = false);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AppShell(
        background: const _GeneralDashboardBackground(),
        wrapBodyInGlass: false,
        animateHeaderSlots: false,
        animateBody: !widget.instantOpen,
        headerBodySpacing: 6,
        padding: const EdgeInsets.fromLTRB(28, 14, 18, 18),
        leadingBuilder: (_, _) => Row(
          children: [
            _GeneralHeaderButton(
              label: _menuOverlayOpen ? 'Cerrar navegación' : 'Navegación',
              icon: _menuOverlayOpen ? Icons.close_rounded : Icons.menu_rounded,
              onTap: () async {
                if (!mounted) return;
                setState(() => _menuOverlayOpen = !_menuOverlayOpen);
              },
            ),
          ],
        ),
        centerBuilder: (_, contentAnim) =>
            _GeneralDashboardBrand(contentAnim: contentAnim),
        trailingBuilder: (_, _) => _GeneralHeaderButton(
          label: 'Cerrar sesión',
          icon: Icons.logout_rounded,
          onTap: _logout,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 2, 8, 8),
          child: _buildBody(),
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
      onOpenOperationalDashboard: _openOperationalDashboard,
      onOpenMenudeo: _openRetailDashboard,
      onOpenMayoreo: _openMayoreoPreviewDashboard,
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
            onOpenMenudeoAnalysis: _openDirectionMenudeoAnalysis,
            onOpenPurchaseOrders: _openDirectionPurchaseOrders,
            onOpenMaintenance: _openDirectionMaintenance,
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
  final Future<void> Function() onOpenMenudeoAnalysis;
  final Future<void> Function() onOpenPurchaseOrders;
  final Future<void> Function() onOpenMaintenance;

  const _DirectionDashboardCanvas({
    required this.onOpenVault,
    required this.onOpenMenudeoAnalysis,
    required this.onOpenPurchaseOrders,
    required this.onOpenMaintenance,
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
              color: Color(0xFF7FD7FF),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: _DirectionVaultHeroCard(onTap: onOpenVault),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'ÁREAS DE ANÁLISIS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
              color: Color(0xFF8CCFFF),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              SizedBox(
                width: 420,
                child: _DirectionPurchaseOrdersEntryCard(
                  onTap: onOpenPurchaseOrders,
                ),
              ),
              SizedBox(
                width: 420,
                child: _DirectionMaintenanceEntryCard(onTap: onOpenMaintenance),
              ),
              SizedBox(
                width: 420,
                child: _DirectionAnalysisEntryCard(
                  title: 'Menudeo',
                  subtitle:
                      'Mercado, efectivo y operación del canal con foco ejecutivo.',
                  badge: 'Mercado activo',
                  icon: Icons.storefront_rounded,
                  onTap: onOpenMenudeoAnalysis,
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

class _DirectionPurchaseOrdersEntryCard extends StatefulWidget {
  final Future<void> Function() onTap;

  const _DirectionPurchaseOrdersEntryCard({required this.onTap});

  @override
  State<_DirectionPurchaseOrdersEntryCard> createState() =>
      _DirectionPurchaseOrdersEntryCardState();
}

class _DirectionPurchaseOrdersEntryCardState
    extends State<_DirectionPurchaseOrdersEntryCard> {
  late final Future<DirectionPurchaseOrdersSummary> _summary =
      DirectionOperationsRepository().loadPurchaseOrdersSummary();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DirectionPurchaseOrdersSummary>(
      future: _summary,
      builder: (context, snapshot) {
        final summary = snapshot.data;
        final badge = summary == null
            ? 'Cargando...'
            : summary.criticalCount > 0
            ? '${summary.criticalCount} críticas'
            : summary.pendingCount > 0
            ? '${summary.pendingCount} pendientes'
            : 'Al día';
        final subtitle = summary == null
            ? 'Autorizaciones y rechazos ejecutivos.'
            : summary.pendingCount == 0
            ? 'No hay compras pendientes de Dirección.'
            : '${summary.pendingCount} por resolver · ${formatMoney(summary.pendingAmount)} pendientes';
        return _DirectionAnalysisEntryCard(
          title: 'Compras OT',
          subtitle: subtitle,
          badge: badge,
          icon: Icons.shopping_cart_checkout_rounded,
          onTap: widget.onTap,
        );
      },
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
          child: _DirectionGlassPanel(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            borderRadius: BorderRadius.circular(26),
            blurSigma: 30,
            fillColor: const Color(0xFF173A78).withValues(alpha: 0.22),
            borderColor: Colors.white.withValues(alpha: 0.26),
            shadowColor: Colors.black.withValues(alpha: 0.10),
            edgeHighlightColor: Colors.white.withValues(alpha: 0.66),
            bevelShadowColor: Colors.black.withValues(alpha: 0.16),
            glowColor: const Color(
              0xFF66D5FF,
            ).withValues(alpha: _hovering ? 0.14 : 0.08),
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
                        color: const Color(0xFF66D5FF).withValues(alpha: 0.14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Icon(widget.icon, color: Colors.white, size: 24),
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
                              color: Colors.white.withValues(alpha: 0.10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Text(
                              widget.badge,
                              style: const TextStyle(
                                color: Color(0xFFBFE7FF),
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

class _DirectionVaultHeroCardState extends State<_DirectionVaultHeroCard> {
  bool _hovering = false;

  Future<({double deposits, double expenses})> _loadTotals() async {
    try {
      final row = await Supabase.instance.client
          .from('cash_taxonomy_configs')
          .select('payload')
          .eq('area', _kDirectionVaultArea)
          .maybeSingle();
      final payload = row?['payload'];
      if (payload is Map && payload['rows'] is List) {
        var deposits = 0.0;
        var expenses = 0.0;
        for (final item in (payload['rows'] as List).whereType<Map>()) {
          final mapped = Map<String, dynamic>.from(item);
          final type = (mapped['type'] ?? '').toString();
          final lines = mapped['lines'];
          var total = 0.0;
          if (lines is List) {
            for (final rawLine in lines.whereType<Map>()) {
              total +=
                  double.tryParse(
                    (Map<String, dynamic>.from(rawLine)['amount'] ?? '0')
                        .toString(),
                  ) ??
                  0;
            }
          }
          if (type == 'deposit') {
            deposits += total;
          } else {
            expenses += total;
          }
        }
        return (deposits: deposits, expenses: expenses);
      }
    } catch (_) {}
    return (
      deposits: _kDirectionVaultDeposits,
      expenses: _kDirectionVaultExpenses,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({double deposits, double expenses})>(
      future: _loadTotals(),
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
                fillColor: const Color(0xFF173A78).withValues(alpha: 0.20),
                borderColor: Colors.white.withValues(alpha: 0.32),
                shadowColor: Colors.black.withValues(
                  alpha: _hovering ? 0.24 : 0.18,
                ),
                edgeHighlightColor: Colors.white.withValues(
                  alpha: _hovering ? 0.86 : 0.78,
                ),
                bevelShadowColor: Colors.black.withValues(alpha: 0.14),
                glowColor: const Color(
                  0xFF66D5FF,
                ).withValues(alpha: _hovering ? 0.22 : 0.14),
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
                                const Color(0xFF163463).withValues(alpha: 0.74),
                              ],
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.account_balance_wallet_rounded,
                                size: 16,
                                color: Color(0xFF94E7FF),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'TOTAL DE BÓVEDA',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.3,
                                  color: Color(0xFFB9DFFF),
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
                            color: Color(0xFFD3E7FF),
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
                  fillColor: const Color(0xFF8FD3FF).withValues(alpha: 0.08),
                  borderColor: Colors.white.withValues(alpha: 0.34),
                  shadowColor: const Color(0xFF5EC8FF).withValues(alpha: 0.08),
                  edgeHighlightColor: Colors.white.withValues(alpha: 0.72),
                  bevelShadowColor: Colors.black.withValues(alpha: 0.10),
                  glowColor: const Color(0xFF6BD5FF).withValues(alpha: 0.10),
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

  const _GeneralHeaderButton({
    required this.label,
    required this.icon,
    required this.onTap,
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
            child: _DirectionGlassPanel(
              width: 178,
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              borderRadius: BorderRadius.circular(16),
              blurSigma: 26,
              fillColor: enabled
                  ? const Color(
                      0xFF8BCFFF,
                    ).withValues(alpha: highlighted ? 0.16 : 0.11)
                  : Colors.white.withValues(alpha: 0.05),
              borderColor: enabled
                  ? Colors.white.withValues(alpha: highlighted ? 0.54 : 0.34)
                  : Colors.white.withValues(alpha: 0.16),
              shadowColor: highlighted
                  ? const Color(0xFF5FE3FF).withValues(alpha: 0.14)
                  : Colors.black.withValues(alpha: 0.06),
              edgeHighlightColor: Colors.white.withValues(alpha: 0.78),
              bevelShadowColor: Colors.black.withValues(alpha: 0.12),
              glowColor: highlighted
                  ? const Color(0xFF5FE3FF).withValues(alpha: 0.18)
                  : const Color(0xFF6BA8FF).withValues(alpha: 0.08),
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
          ),
        ),
      ),
    );
  }
}

class _GeneralDashboardBackground extends StatelessWidget {
  const _GeneralDashboardBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF04142E), Color(0xFF0C2147), Color(0xFF133963)],
            ),
          ),
          child: SizedBox.expand(),
        ),
        Positioned(
          left: -250,
          top: -120,
          child: _bubbleCircle(
            700,
            const LinearGradient(
              colors: [Color(0xFFF3F8FF), Color(0xFF7AAFFF)],
            ),
          ),
        ),
        Positioned(
          right: -200,
          top: -80,
          child: _bubbleCircle(
            600,
            const LinearGradient(
              colors: [Color(0xFF4BFFE0), Color(0xFF00B7FF)],
            ),
          ),
        ),
        Positioned(
          left: -150,
          bottom: -250,
          child: _bubbleCircle(
            600,
            const LinearGradient(
              colors: [Color(0xFF224CFF), Color(0xFF7D63FF)],
            ),
          ),
        ),
        Positioned(
          right: -120,
          bottom: -120,
          child: IgnorePointer(
            child: _bubblePill(
              width: 300,
              height: 500,
              radius: 200,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF39F0E1), Color(0xFF0C8CFF)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bubbleCircle(double size, Gradient gradient) {
    final lead = _gradientLead(gradient);
    final trail = _gradientTrail(gradient);
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              blurRadius: 130,
              spreadRadius: 14,
              color: lead.withValues(alpha: 0.16),
            ),
            BoxShadow(
              blurRadius: 72,
              spreadRadius: 0,
              color: trail.withValues(alpha: 0.10),
            ),
          ],
        ),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                    width: 1.1,
                  ),
                  gradient: RadialGradient(
                    center: const Alignment(0.18, 0.10),
                    radius: 0.98,
                    colors: [
                      Colors.white.withValues(alpha: 0.02),
                      lead.withValues(alpha: 0.08),
                      trail.withValues(alpha: 0.17),
                      trail.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.14, 0.42, 0.78, 1.0],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.22, -0.28),
                    radius: 0.52,
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.035),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.36, 1.0],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(0.34, 0.42),
                    radius: 0.88,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.10),
                    ],
                    stops: const [0.0, 0.58, 1.0],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bubblePill({
    required double width,
    required double height,
    required double radius,
    required Gradient gradient,
  }) {
    final lead = _gradientLead(gradient);
    final trail = _gradientTrail(gradient);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            blurRadius: 120,
            spreadRadius: 8,
            color: lead.withValues(alpha: 0.16),
          ),
          BoxShadow(
            blurRadius: 72,
            spreadRadius: 0,
            color: trail.withValues(alpha: 0.10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.04),
                  radius: 1.04,
                  colors: [
                    Colors.white.withValues(alpha: 0.015),
                    lead.withValues(alpha: 0.05),
                    trail.withValues(alpha: 0.16),
                    trail.withValues(alpha: 0.04),
                  ],
                  stops: const [0.0, 0.22, 0.72, 1.0],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                gradient: RadialGradient(
                  center: const Alignment(-0.10, -0.92),
                  radius: 0.44,
                  colors: [
                    Colors.white.withValues(alpha: 0.10),
                    Colors.white.withValues(alpha: 0.025),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.34, 1.0],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                gradient: RadialGradient(
                  center: const Alignment(0.28, 0.90),
                  radius: 1.05,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.08),
                  ],
                  stops: const [0.0, 0.62, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _gradientLead(Gradient gradient) {
    if (gradient is LinearGradient && gradient.colors.isNotEmpty) {
      return gradient.colors.first;
    }
    if (gradient is RadialGradient && gradient.colors.isNotEmpty) {
      return gradient.colors.first;
    }
    return Colors.white;
  }

  Color _gradientTrail(Gradient gradient) {
    if (gradient is LinearGradient && gradient.colors.isNotEmpty) {
      return gradient.colors.last;
    }
    if (gradient is RadialGradient && gradient.colors.isNotEmpty) {
      return gradient.colors.last;
    }
    return Colors.white;
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
  final Future<void> Function()? onOpenOperationalDashboard;
  final Future<void> Function()? onOpenMenudeo;
  final Future<void> Function()? onOpenMayoreo;

  const _GeneralDashboardSideMenu({
    required this.directionExpanded,
    required this.areasExpanded,
    this.onToggleDirectionExpanded,
    this.onToggleAreasExpanded,
    this.onOpenGeneralDashboard,
    this.onOpenDirectionCashWorkspace,
    this.onOpenDirectionCashCatalog,
    this.onOpenDirectionMenudeoAnalysis,
    this.onOpenOperationalDashboard,
    this.onOpenMenudeo,
    this.onOpenMayoreo,
  });

  @override
  Widget build(BuildContext context) {
    return _DirectionGlassPanel(
      borderRadius: BorderRadius.circular(24),
      blurSigma: 30,
      fillColor: const Color(0xFF173A78).withValues(alpha: 0.28),
      borderColor: Colors.white.withValues(alpha: 0.34),
      shadowColor: const Color(0xFF4DC7FF).withValues(alpha: 0.08),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.72),
      bevelShadowColor: Colors.black.withValues(alpha: 0.16),
      glowColor: const Color(0xFF66D5FF).withValues(alpha: 0.12),
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
                  color: Color(0xB8D5E5FF),
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
      fillColor: const Color(0xFF1D468A).withValues(alpha: 0.22),
      borderColor: Colors.white.withValues(alpha: 0.28),
      shadowColor: const Color(0xFF58C9FF).withValues(alpha: 0.05),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.66),
      bevelShadowColor: Colors.black.withValues(alpha: 0.14),
      glowColor: const Color(0xFF6DD7FF).withValues(alpha: 0.08),
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
                      color: Color(0xFFE6F2FF),
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
                ? const Color(0xFF83D3FF).withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.current
                  ? const Color(0xFFFFC979).withValues(alpha: 0.30)
                  : Colors.white.withValues(alpha: 0.18),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: highlighted ? 0.16 : 0.08),
                const Color(
                  0xFF66CCFF,
                ).withValues(alpha: highlighted ? 0.10 : 0.04),
                const Color(0xFF1A3E7C).withValues(alpha: 0.14),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: highlighted ? 18 : 8,
                offset: const Offset(0, 5),
                color: highlighted
                    ? const Color(0xFF68D9FF).withValues(alpha: 0.12)
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
                        color: Color(0xB9D9E9FF),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.current)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: Color(0xFFFFD28B),
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
    this.fillColor = const Color(0x141D4A88),
    this.borderColor = const Color(0x52FFFFFF),
    this.shadowColor = const Color(0x12000000),
    this.edgeHighlightColor = const Color(0xCCFFFFFF),
    this.bevelShadowColor = const Color(0x18000000),
    this.glowColor = const Color(0x105BD6FF),
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
                const Color(0xFF7AD9FF).withValues(alpha: 0.04),
                const Color(0xFF102D61).withValues(alpha: 0.16),
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
                          const Color(0xFF95EAFF).withValues(alpha: 0.08),
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
                          const Color(0xFF76D9FF).withValues(alpha: 0.03),
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
