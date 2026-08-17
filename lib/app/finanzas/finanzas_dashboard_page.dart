import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../compras/compras_area_chrome.dart';
import '../compras/compras_tickets_store.dart';
import '../compras/compras_dashboard_page.dart';
import '../dashboard/general_dashboard_page.dart';
import '../management_reports/management_reports_registry.dart';
import '../management_reports/management_reports_widgets.dart';
import '../management_reports/management_supervision_page.dart';
import '../shared/app_shell.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/number_formatters.dart';
import 'finanzas_bank_accounts_page.dart';
import 'finanzas_bank_accounts_store.dart';
import 'finanzas_catalog_page.dart';
import 'finanzas_company_identity.dart';
import 'finanzas_company_directory_page.dart';
import 'finanzas_due_alerts_store.dart';
import 'finanzas_fixed_payments_page.dart';
import 'finanzas_fixed_payments_store.dart';
import 'finanzas_financial_rules.dart';
import 'finanzas_payment_center_page.dart';
import 'finanzas_provider_accounts_page.dart';
import 'finanzas_provider_accounts_store.dart';
import 'finanzas_theme.dart';

class FinanzasDashboardPage extends StatefulWidget {
  final bool instantOpen;

  const FinanzasDashboardPage({super.key, this.instantOpen = false});

  @override
  State<FinanzasDashboardPage> createState() => _FinanzasDashboardPageState();
}

class _FinanzasDashboardPageState extends State<FinanzasDashboardPage> {
  bool _menuOpen = false;
  bool _loading = true;
  bool _canReturnToDirection = false;
  bool _canAccessComprasArea = false;
  _FinanzasDashboardSummary _summary = const _FinanzasDashboardSummary.empty();
  bool _dueNotificationPresented = false;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveNavigationAccess());
    unawaited(_loadDashboard());
  }

  Future<void> _resolveNavigationAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(() {
      _canReturnToDirection = AuthAccess.isDirectionRole(profile);
      _canAccessComprasArea = AuthAccess.canAccessComprasArea(profile);
    });
  }

  Future<void> _loadDashboard({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    final results = await Future.wait<dynamic>([
      FinanzasBankAccountsStore.loadMovements(),
      FinanzasBankAccountsStore.loadOpenClientAccounts(),
      FinanzasProviderAccountsStore.loadInvoices(),
      FinanzasFixedPaymentsStore.loadPayments(),
      FinanzasProviderAccountsStore.loadAgreements(),
      FinanzasDueAlertsStore.loadSummary(),
      ComprasTicketsStore.loadTickets(),
    ]);
    if (!mounted) return;
    final movements = results[0] as List<FinanzasBankMovementRecord>;
    final openClientAccounts =
        results[1] as List<FinanzasClientPaymentAccountRecord>;
    final invoices = results[2] as List<FinanzasSupplierInvoiceRecord>;
    final fixedPayments = results[3] as List<FinanzasFixedPaymentRecord>;
    final agreements = results[4] as List<FinanzasSupplierAgreementRecord>;
    final dueAlerts = results[5] as FinanzasDueAlertsSummary;
    final tickets = results[6] as List<ComprasTicketRecord>;
    setState(() {
      _summary = _buildFinanzasDashboardSummary(
        movements: movements,
        openClientAccounts: openClientAccounts,
        invoices: invoices,
        fixedPayments: fixedPayments,
        agreements: agreements,
        dueAlerts: dueAlerts,
        tickets: tickets,
      );
      _loading = false;
    });
    unawaited(_presentDueNotificationIfNeeded(dueAlerts));
  }

  Future<void> _presentDueNotificationIfNeeded(
    FinanzasDueAlertsSummary dueAlerts,
  ) async {
    if (!mounted || _dueNotificationPresented) return;
    if (dueAlerts.totalCount <= 0 || dueAlerts.items.isEmpty) return;
    if (!FinanzasDueAlertsSessionGate.registerPresentation(
      FinanzasDueAlertsSessionScope.finanzasDashboard,
    )) {
      return;
    }
    _dueNotificationPresented = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _FinanzasDueNotificationDialog(
          summary: dueAlerts,
          visibleItems: dueAlerts.items.toList(growable: false),
          onOpenPaymentCenter: () async {
            Navigator.of(dialogContext).pop();
            await _openPaymentCenter();
          },
        );
      },
    );
  }

  Future<void> _openDueAlertsDialog() async {
    final dueAlerts = _summary.dueAlerts;
    if (!mounted || dueAlerts.totalCount <= 0 || dueAlerts.items.isEmpty) {
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _FinanzasDueNotificationDialog(
          summary: dueAlerts,
          visibleItems: dueAlerts.items.toList(growable: false),
          onOpenPaymentCenter: () async {
            Navigator.of(dialogContext).pop();
            await _openPaymentCenter();
          },
        );
      },
    );
  }

  Future<void> _logout() => signOutAndRouteToLogin(context);

  Future<void> _openCompras() async {
    await Navigator.of(
      context,
    ).push(appPageRoute(page: const ComprasDashboardPage(instantOpen: true)));
  }

  Future<void> _openCatalog() async {
    await Navigator.of(
      context,
    ).push(appPageRoute(page: const FinanzasCatalogPage(instantOpen: true)));
  }

  Future<void> _openDirectory() async {
    await Navigator.of(context).push(
      appPageRoute(page: const FinanzasCompanyDirectoryPage(instantOpen: true)),
    );
  }

  Future<void> _openProviderAccounts() async {
    await Navigator.of(context).push(
      appPageRoute(page: const FinanzasProviderAccountsPage(instantOpen: true)),
    );
  }

  Future<void> _openPaymentCenter() async {
    await Navigator.of(context).push(
      appPageRoute(page: const FinanzasPaymentCenterPage(instantOpen: true)),
    );
  }

  Future<void> _openBankAccounts() async {
    await Navigator.of(context).push(
      appPageRoute(page: const FinanzasBankAccountsPage(instantOpen: true)),
    );
  }

  Future<void> _openFixedPayments() async {
    await Navigator.of(context).push(
      appPageRoute(page: const FinanzasFixedPaymentsPage(instantOpen: true)),
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

  Future<void> _openDirectionDashboard() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
    );
  }

  void _handleNavigationAction(String label) {
    switch (label) {
      case 'Dashboard Finanzas':
        return;
      case 'Centro de pagos':
        unawaited(_openPaymentCenter());
        return;
      case 'Cuentas por Proveedor':
        unawaited(_openProviderAccounts());
        return;
      case 'Cuentas Bancarias':
        unawaited(_openBankAccounts());
        return;
      case 'Pagos fijos':
        unawaited(_openFixedPayments());
        return;
      case 'Catálogo Finanzas':
        unawaited(_openCatalog());
        return;
      case 'Directorio Empresas':
        unawaited(_openDirectory());
        return;
      case 'Dashboard Compras':
        unawaited(_openCompras());
        return;
      case 'Dashboard Dirección':
        unawaited(_openDirectionDashboard());
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AreaThemeScope(
      tokens: finanzasAreaTokens,
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape && _menuOpen) {
            setState(() => _menuOpen = false);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AppShell(
          background: const FinanzasAreaBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 8,
          padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
          leadingBuilder: (_, _) => _FinanzasHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegación',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, _) => const _FinanzasDashboardHeaderBrand(),
          trailingBuilder: (_, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FinanzasHeaderButton(
                label: '',
                icon: Icons.mail_outline_rounded,
                compact: true,
                iconOnly: true,
                onTap: () => openComprasMailHostinger(context),
              ),
              const SizedBox(width: 10),
              _FinanzasHeaderButton(
                label: 'Pendientes',
                icon: Icons.notifications_none_rounded,
                notificationCount: _summary.dueAlerts.totalCount,
                onTap: _openDueAlertsDialog,
              ),
              const SizedBox(width: 10),
              _FinanzasHeaderButton(
                label: 'Cerrar sesión',
                icon: Icons.logout_rounded,
                onTap: _logout,
              ),
            ],
          ),
          child: Stack(
            children: [
              _FinanzasDashboardBody(
                loading: _loading,
                summary: _summary,
                onRefresh: () => _loadDashboard(silent: false),
                onOpenManagementSupervision: _openManagementSupervision,
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_menuOpen,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _menuOpen ? 1 : 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _menuOpen = false),
                      child: Container(
                        color: const Color(0xFF8B4A1A).withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: _menuOpen ? 0 : -332,
                top: 0,
                bottom: 0,
                width: 320,
                child: IgnorePointer(
                  ignoring: !_menuOpen,
                  child: FinanzasAreaSidePanel(
                    currentLabel: 'Dashboard Finanzas',
                    canReturnToDirection: _canReturnToDirection,
                    canAccessComprasArea: _canAccessComprasArea,
                    onNavigate: _handleNavigationAction,
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

class _FinanzasDashboardBody extends StatelessWidget {
  final bool loading;
  final _FinanzasDashboardSummary summary;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onOpenManagementSupervision;

  const _FinanzasDashboardBody({
    required this.loading,
    required this.summary,
    required this.onRefresh,
    required this.onOpenManagementSupervision,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(56, 0, 6, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DashboardTopStrip(
                loading: loading,
                summary: summary,
                onRefresh: onRefresh,
              ),
              const SizedBox(height: 18),
              ManagementAreaReportPanel(
                areaKey: ManagementAreaKey.finanzas,
                subtitleOverride:
                    'El responsable de Finanzas debe generar aquí sus cortes, estudiarlos y llegar a la junta con pagos urgentes, presión de caja y decisiones propuestas.',
                showOpenHubButton: true,
                onOpenSupervisionHub: onOpenManagementSupervision,
              ),
              const SizedBox(height: 18),
              _FinanceMetricCardsRow(loading: loading, summary: summary),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _LiquidityBlock(loading: loading, summary: summary),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _PayablesBlock(loading: loading, summary: summary),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ExecutionBlock(loading: loading, summary: summary),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _ProviderRiskBlock(
                      loading: loading,
                      summary: summary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _PurchasesCrossBlock(
                      loading: loading,
                      summary: summary,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _ExecutiveAlertsBlock(
                      loading: loading,
                      summary: summary,
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

class _DashboardTopStrip extends StatelessWidget {
  final bool loading;
  final _FinanzasDashboardSummary summary;
  final Future<void> Function() onRefresh;

  const _DashboardTopStrip({
    required this.loading,
    required this.summary,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return ContractGlassCard(
      borderRadius: BorderRadius.circular(30),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard Finanzas',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: tokens.onGlass,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Liquidez real, pasivo abierto y tensión de caja con base en bancos, facturas de proveedor y pagos fijos.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: tokens.badgeText,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            children: [
              _MiniPeriodBadge(
                label: 'Mes actual',
                accent: tokens.primaryStrong,
              ),
              _MiniPeriodBadge(label: 'Próx. 7 días', accent: tokens.primary),
              _MiniPeriodBadge(
                label: loading
                    ? 'Cargando'
                    : '${summary.openInvoiceCount} facturas abiertas',
                accent: kFinanzasCopper,
              ),
              if (!loading && summary.dueAlerts.totalCount > 0)
                _MiniPeriodBadge(
                  label: '${summary.dueAlerts.totalCount} vencimientos foco',
                  accent:
                      summary.dueAlerts.overdueCount > 0 ||
                          summary.dueAlerts.dueTodayCount > 0
                      ? kFinanzasCoral
                      : kFinanzasAmber,
                ),
              _RefreshBadge(onTap: onRefresh),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinanceMetricCardsRow extends StatelessWidget {
  final bool loading;
  final _FinanzasDashboardSummary summary;

  const _FinanceMetricCardsRow({required this.loading, required this.summary});

  @override
  Widget build(BuildContext context) {
    const spacing = 16.0;
    const preferredCardWidth = 220.0;
    const cardHeight = 164.0;
    final cards = <_FinanceMetricCardData>[
      _FinanceMetricCardData(
        title: 'Saldo disponible',
        value: loading ? 'Cargando...' : formatMoney(summary.availableBalance),
        detail: loading ? 'Leyendo movimientos' : summary.availableDetail,
        icon: Icons.account_balance_wallet_outlined,
        accent: kFinanzasSage,
      ),
      _FinanceMetricCardData(
        title: 'Cuentas por pagar',
        value: loading ? 'Cargando...' : formatMoney(summary.accountsPayable),
        detail: loading
            ? 'Leyendo facturas'
            : '${summary.openInvoiceCount} facturas abiertas',
        icon: Icons.receipt_long_outlined,
        accent: kFinanzasAmber,
      ),
      _FinanceMetricCardData(
        title: 'Vencido',
        value: loading ? 'Cargando...' : formatMoney(summary.overdueBalance),
        detail: loading
            ? 'Revisando vencimientos'
            : '${summary.overdueInvoiceCount} facturas fuera de tiempo',
        icon: Icons.warning_amber_rounded,
        accent: kFinanzasCoral,
      ),
      _FinanceMetricCardData(
        title: 'Compromisos del mes',
        value: loading ? 'Cargando...' : formatMoney(summary.monthCommitments),
        detail: loading
            ? 'Calculando calendario'
            : summary.monthCommitmentsDetail,
        icon: Icons.event_note_rounded,
        accent: kFinanzasBronze,
      ),
      _FinanceMetricCardData(
        title: 'Flujo neto proyectado',
        value: loading ? 'Cargando...' : formatMoney(summary.projectedNetFlow),
        detail: loading
            ? 'Calculando corto plazo'
            : summary.projectedNetFlowDetail,
        icon: Icons.ssid_chart_rounded,
        accent: kFinanzasCopper,
      ),
      _FinanceMetricCardData(
        title: 'Presión de caja',
        value: loading ? 'Cargando...' : summary.cashPressureLabel,
        detail: loading ? 'Midiendo tensión' : summary.cashPressureDetail,
        icon: Icons.speed_rounded,
        accent: summary.cashPressureAccent,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSpacing = spacing * (cards.length - 1);
        final fittedWidth =
            (constraints.maxWidth - totalSpacing) / cards.length;
        final cardWidth = fittedWidth >= 184 ? fittedWidth : preferredCardWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < cards.length; index += 1) ...[
                SizedBox(
                  width: cardWidth,
                  height: cardHeight,
                  child: _FinanceMetricCard(data: cards[index]),
                ),
                if (index != cards.length - 1) const SizedBox(width: spacing),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _FinanceMetricCardData {
  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color accent;

  const _FinanceMetricCardData({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.accent,
  });
}

class _FinanceMetricCard extends StatelessWidget {
  final _FinanceMetricCardData data;

  const _FinanceMetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return FinanzasGlassPanel(
      borderRadius: BorderRadius.circular(26),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      fillColor: kFinanzasPanelSurfaceStrong.withValues(alpha: 0.94),
      borderColor: data.accent.withValues(alpha: 0.30),
      glowColor: data.accent.withValues(alpha: 0.22),
      edgeHighlightColor: kFinanzasOrange.withValues(alpha: 0.12),
      child: SizedBox(
        height: 164,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: data.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: data.accent.withValues(alpha: 0.30)),
              ),
              child: Icon(data.icon, color: data.accent, size: 26),
            ),
            const SizedBox(height: 14),
            Text(
              data.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: kFinanzasInk,
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                data.value,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                data.detail,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kFinanzasMutedInk,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiquidityBlock extends StatelessWidget {
  final bool loading;
  final _FinanzasDashboardSummary summary;

  const _LiquidityBlock({required this.loading, required this.summary});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return ContractGlassCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DashboardSectionHeading(
            title: 'Liquidez y bancos',
            subtitle:
                'Caja neta, cobros abiertos y concentración actual por cuenta bancaria.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InlineMetricChip(
                label: 'Disponible',
                value: loading ? '...' : formatMoney(summary.availableBalance),
              ),
              _InlineMetricChip(
                label: 'Cobros abiertos',
                value: loading
                    ? '...'
                    : formatMoney(summary.openClientCollections),
              ),
              _InlineMetricChip(
                label: 'Corto plazo',
                value: loading
                    ? '...'
                    : formatMoney(summary.shortTermCommitments),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: tokens.fieldSurface.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: tokens.border.withValues(alpha: 0.70)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Disponible vs compromiso inmediato',
                        style: TextStyle(
                          color: tokens.onGlass,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      loading ? '...' : summary.shortTermCoverageLabel,
                      style: TextStyle(
                        color: summary.cashPressureAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 12,
                    value: summary.shortTermCoverageProgress,
                    backgroundColor: tokens.badgeBackground.withValues(
                      alpha: 0.62,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      summary.cashPressureAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  loading
                      ? 'Leyendo movimientos bancarios y compromisos próximos.'
                      : '${formatMoney(summary.availableBalance)} disponibles frente a ${formatMoney(summary.shortTermCommitments)} comprometidos en el frente inmediato.',
                  style: TextStyle(
                    color: tokens.badgeText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _InsightHeroCard(
            accent: summary.cashPressureAccent,
            ringValue: summary.shortTermCoverageProgress,
            ringLabel: loading ? '...' : summary.shortTermCoverageLabel,
            ringCaption: 'cobertura',
            title: 'Pulso de liquidez',
            subtitle: loading
                ? 'Leyendo base de caja.'
                : '${formatMoney(summary.availableBalance)} disponibles frente a ${formatMoney(summary.shortTermCommitments)} comprometidos en el frente inmediato.',
            stats: [
              _HeroStat(
                label: 'Disponible',
                value: loading ? '...' : formatMoney(summary.availableBalance),
              ),
              _HeroStat(
                label: 'Cobros abiertos',
                value: loading
                    ? '...'
                    : formatMoney(summary.openClientCollections),
              ),
              _HeroStat(
                label: 'Compromiso',
                value: loading
                    ? '...'
                    : formatMoney(summary.shortTermCommitments),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Saldo por banco',
            style: TextStyle(
              color: tokens.onGlass,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (summary.bankBalances.isEmpty)
            const _DashboardEmptyState(
              icon: Icons.account_balance_outlined,
              title: 'Sin movimientos bancarios',
              subtitle:
                  'Cuando existan cargos y abonos aquí aparecerá la distribución real de liquidez.',
            )
          else
            Column(
              children: summary.bankBalances
                  .take(5)
                  .map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _BarRow(
                        label: row.label,
                        share: row.share,
                        accent: kFinanzasCopper,
                        value: formatMoney(row.balance),
                        secondary:
                            '${row.company} · ${row.branch} · ${row.accountKey}',
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _PayablesBlock extends StatelessWidget {
  final bool loading;
  final _FinanzasDashboardSummary summary;

  const _PayablesBlock({required this.loading, required this.summary});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return ContractGlassCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DashboardSectionHeading(
            title: 'Cuentas por pagar',
            subtitle:
                'Pasivo abierto, vencimientos cercanos y concentración de saldo por proveedor.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InlineMetricChip(
                label: 'Abierto',
                value: loading ? '...' : formatMoney(summary.accountsPayable),
              ),
              _InlineMetricChip(
                label: 'Vencido',
                value: loading ? '...' : formatMoney(summary.overdueBalance),
              ),
              _InlineMetricChip(
                label: 'Próx. 7 días',
                value: loading ? '...' : formatMoney(summary.dueIn7Days),
              ),
              _InlineMetricChip(
                label: 'Próx. 30 días',
                value: loading ? '...' : formatMoney(summary.dueIn30Days),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: tokens.fieldSurface.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: tokens.border.withValues(alpha: 0.70)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Antigüedad operativa',
                        style: TextStyle(
                          color: tokens.onGlass,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '${summary.overdueInvoiceCount} vencidas',
                      style: TextStyle(
                        color: kFinanzasCoral,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _AgingBar(summary: summary),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 18,
                  runSpacing: 10,
                  children: [
                    _LegendDot(label: 'Vencido', color: kFinanzasCoral),
                    _LegendDot(label: '0-7 días', color: kFinanzasAmber),
                    _LegendDot(label: '8-30 días', color: kFinanzasCopper),
                    _LegendDot(label: 'Más adelante', color: kFinanzasTaupe),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _InsightHeroCard(
            accent: kFinanzasCoral,
            ringValue: summary.accountsPayable <= 0.009
                ? 0
                : (summary.overdueBalance / summary.accountsPayable).clamp(
                    0.0,
                    1.0,
                  ),
            ringLabel: summary.accountsPayable <= 0.009
                ? '0.0%'
                : '${formatDecimal((summary.overdueBalance / summary.accountsPayable) * 100, decimals: 1)}%',
            ringCaption: 'vencido',
            title: 'Pulso del pasivo',
            subtitle: loading
                ? 'Leyendo vencimientos.'
                : '${formatMoney(summary.accountsPayable)} abiertos, de los cuales ${formatMoney(summary.overdueBalance)} ya están vencidos.',
            stats: [
              _HeroStat(
                label: 'Abierto',
                value: loading ? '...' : formatMoney(summary.accountsPayable),
              ),
              _HeroStat(
                label: '7 días',
                value: loading ? '...' : formatMoney(summary.dueIn7Days),
              ),
              _HeroStat(
                label: '30 días',
                value: loading ? '...' : formatMoney(summary.dueIn30Days),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Top proveedores por saldo',
            style: TextStyle(
              color: tokens.onGlass,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (summary.providerBalances.isEmpty)
            const _DashboardEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Sin facturas abiertas',
              subtitle:
                  'Cuando exista pasivo de proveedor aquí aparecerán los saldos más relevantes.',
            )
          else
            Column(
              children: summary.providerBalances
                  .take(5)
                  .map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _BarRow(
                        label: row.providerName,
                        share: row.share,
                        accent: row.overdueAmount > 0.009
                            ? kFinanzasCoral
                            : finanzasAreaTokens.primarySoft,
                        value: formatMoney(row.balance),
                        secondary: row.overdueAmount > 0.009
                            ? '${formatMoney(row.overdueAmount)} vencidos'
                            : '${row.invoiceCount} facturas abiertas',
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _ExecutionBlock extends StatelessWidget {
  final bool loading;
  final _FinanzasDashboardSummary summary;

  const _ExecutionBlock({required this.loading, required this.summary});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return ContractGlassCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DashboardSectionHeading(
            title: 'Ejecución de pagos',
            subtitle:
                'Atención del mes, carga fija pendiente y sugerencias simples de acción inmediata.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InlineMetricChip(
                label: 'Ejecutado mes',
                value: loading
                    ? '...'
                    : formatMoney(summary.executedPaymentsMonth),
              ),
              _InlineMetricChip(
                label: 'Pendiente mes',
                value: loading
                    ? '...'
                    : formatMoney(summary.pendingPaymentsMonth),
              ),
              _InlineMetricChip(
                label: 'Fijos pagados',
                value: loading
                    ? '...'
                    : formatMoney(summary.fixedExecutedMonthAmount),
              ),
              _InlineMetricChip(
                label: 'Fijos pendientes',
                value: loading
                    ? '...'
                    : formatMoney(summary.fixedPendingMonthAmount),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InsightHeroCard(
            accent: kFinanzasBronze,
            ringValue: summary.monthCommitments <= 0.009
                ? 0
                : (summary.executedPaymentsMonth / summary.monthCommitments)
                      .clamp(0.0, 1.0),
            ringLabel: summary.monthCommitments <= 0.009
                ? '0.0%'
                : '${formatDecimal((summary.executedPaymentsMonth / summary.monthCommitments) * 100, decimals: 1)}%',
            ringCaption: 'ejecutado',
            title: 'Avance del mes',
            subtitle: loading
                ? 'Leyendo ejecución.'
                : '${formatMoney(summary.executedPaymentsMonth)} ejecutados contra ${formatMoney(summary.monthCommitments)} comprometidos durante el mes.',
            stats: [
              _HeroStat(
                label: 'Ejecutado',
                value: loading
                    ? '...'
                    : formatMoney(summary.executedPaymentsMonth),
              ),
              _HeroStat(
                label: 'Pendiente',
                value: loading
                    ? '...'
                    : formatMoney(summary.pendingPaymentsMonth),
              ),
              _HeroStat(
                label: 'Sugeridos',
                value: loading ? '...' : '${summary.paymentSuggestions.length}',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Sugeridos hoy',
            style: TextStyle(
              color: tokens.onGlass,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (summary.paymentSuggestions.isEmpty)
            const _DashboardEmptyState(
              icon: Icons.playlist_add_check_circle_outlined,
              title: 'Sin pagos sugeridos',
              subtitle:
                  'Cuando existan vencimientos, prioridades o pagos fijos sensibles aparecerán aquí como guía ejecutiva.',
            )
          else
            Column(
              children: summary.paymentSuggestions
                  .take(5)
                  .map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SuggestionRow(row: row),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _ProviderRiskBlock extends StatelessWidget {
  final bool loading;
  final _FinanzasDashboardSummary summary;

  const _ProviderRiskBlock({required this.loading, required this.summary});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return ContractGlassCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DashboardSectionHeading(
            title: 'Riesgo / concentración por proveedor',
            subtitle:
                'Exposición abierta, convenios activos y señales de atraso para lectura rápida.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InlineMetricChip(
                label: 'Convenios activos',
                value: loading ? '...' : '${summary.activeAgreementCount}',
              ),
              _InlineMetricChip(
                label: 'Convenios atrasados',
                value: loading ? '...' : '${summary.delayedAgreementCount}',
              ),
              _InlineMetricChip(
                label: 'Facturas críticas',
                value: loading ? '...' : '${summary.criticalInvoiceCount}',
              ),
              _InlineMetricChip(
                label: 'Proveedor líder',
                value: loading ? '...' : summary.leadingProviderLabel,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InsightHeroCard(
            accent: summary.providerRiskRows.isEmpty
                ? kFinanzasCopper
                : summary.providerRiskRows.first.riskColor,
            ringValue: summary.providerRiskRows.isEmpty
                ? 0
                : (summary.providerRiskRows.first.share / 100).clamp(0.0, 1.0),
            ringLabel: summary.providerRiskRows.isEmpty
                ? '0.0%'
                : '${formatDecimal(summary.providerRiskRows.first.share, decimals: 1)}%',
            ringCaption: 'del pasivo',
            title: 'Concentración líder',
            subtitle: loading
                ? 'Calculando foco proveedor.'
                : summary.providerRiskRows.isEmpty
                ? 'Sin concentración visible.'
                : '${summary.providerRiskRows.first.providerName} es hoy el proveedor con mayor señal de riesgo y concentración.',
            stats: [
              _HeroStat(
                label: 'Convenios',
                value: loading ? '...' : '${summary.activeAgreementCount}',
              ),
              _HeroStat(
                label: 'Atrasados',
                value: loading ? '...' : '${summary.delayedAgreementCount}',
              ),
              _HeroStat(
                label: 'Críticas',
                value: loading ? '...' : '${summary.criticalInvoiceCount}',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Proveedores en foco',
            style: TextStyle(
              color: tokens.onGlass,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (summary.providerRiskRows.isEmpty)
            const _DashboardEmptyState(
              icon: Icons.groups_2_outlined,
              title: 'Sin focos de riesgo proveedor',
              subtitle:
                  'Cuando existan saldos abiertos o convenios sensibles aquí aparecerán los proveedores más delicados.',
            )
          else
            Column(
              children: summary.providerRiskRows
                  .take(5)
                  .map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _RiskRow(row: row),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _PurchasesCrossBlock extends StatelessWidget {
  final bool loading;
  final _FinanzasDashboardSummary summary;

  const _PurchasesCrossBlock({required this.loading, required this.summary});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return ContractGlassCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DashboardSectionHeading(
            title: 'Cruce con compras',
            subtitle:
                'Lectura del impacto de tickets, factura y pago sobre la presión financiera del mes.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InlineMetricChip(
                label: 'Compras mes',
                value: loading
                    ? '...'
                    : formatMoney(summary.monthPurchaseAmount),
              ),
              _InlineMetricChip(
                label: 'Sin factura',
                value: loading ? '...' : '${summary.noInvoiceTicketCount}',
              ),
              _InlineMetricChip(
                label: 'Pend. pago',
                value: loading ? '...' : '${summary.pendingPaymentTicketCount}',
              ),
              _InlineMetricChip(
                label: 'Kg mes',
                value: loading
                    ? '...'
                    : '${formatDecimal(summary.monthPurchaseWeight)} kg',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!loading &&
              (summary.purchaseProviderRows.isNotEmpty ||
                  summary.purchaseMaterialRows.isNotEmpty))
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (summary.purchaseProviderRows.isNotEmpty)
                  Expanded(
                    child: _MiniInsightCard(
                      accent: kFinanzasCopper,
                      title: 'Proveedor líder',
                      ringValue:
                          (summary.purchaseProviderRows.first.share / 100)
                              .clamp(0.0, 1.0),
                      ringLabel:
                          '${formatDecimal(summary.purchaseProviderRows.first.share, decimals: 1)}%',
                      primary: summary.purchaseProviderRows.first.label,
                      secondary: formatMoney(
                        summary.purchaseProviderRows.first.amount,
                      ),
                    ),
                  ),
                if (summary.purchaseProviderRows.isNotEmpty &&
                    summary.purchaseMaterialRows.isNotEmpty)
                  const SizedBox(width: 12),
                if (summary.purchaseMaterialRows.isNotEmpty)
                  Expanded(
                    child: _MiniInsightCard(
                      accent: kFinanzasTaupe,
                      title: 'Material líder',
                      ringValue:
                          (summary.purchaseMaterialRows.first.share / 100)
                              .clamp(0.0, 1.0),
                      ringLabel:
                          '${formatDecimal(summary.purchaseMaterialRows.first.share, decimals: 1)}%',
                      primary: summary.purchaseMaterialRows.first.label,
                      secondary:
                          '${formatDecimal(summary.purchaseMaterialRows.first.weight)} kg',
                    ),
                  ),
              ],
            ),
          if (!loading &&
              (summary.purchaseProviderRows.isNotEmpty ||
                  summary.purchaseMaterialRows.isNotEmpty))
            const SizedBox(height: 14),
          Text(
            'Concentración operativa',
            style: TextStyle(
              color: tokens.onGlass,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (summary.purchaseProviderRows.isEmpty &&
              summary.purchaseMaterialRows.isEmpty)
            const _DashboardEmptyState(
              icon: Icons.shopping_cart_checkout_rounded,
              title: 'Sin tickets de compras',
              subtitle:
                  'Cuando existan tickets del mes aquí aparecerá el cruce operativo que más carga a Finanzas.',
            )
          else
            Column(
              children: [
                if (summary.purchaseProviderRows.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _BarRow(
                      label:
                          'Proveedor líder · ${summary.purchaseProviderRows.first.label}',
                      share: summary.purchaseProviderRows.first.share,
                      accent: kFinanzasCopper,
                      value: formatMoney(
                        summary.purchaseProviderRows.first.amount,
                      ),
                      secondary:
                          '${summary.purchaseProviderRows.first.share.toStringAsFixed(1)}% del importe de compras del mes',
                    ),
                  ),
                if (summary.purchaseMaterialRows.isNotEmpty)
                  _BarRow(
                    label:
                        'Material líder · ${summary.purchaseMaterialRows.first.label}',
                    share: summary.purchaseMaterialRows.first.share,
                    accent: kFinanzasTaupe,
                    value: formatMoney(
                      summary.purchaseMaterialRows.first.amount,
                    ),
                    secondary:
                        '${formatDecimal(summary.purchaseMaterialRows.first.weight)} kg · ${summary.purchaseMaterialRows.first.share.toStringAsFixed(1)}% del total',
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ExecutiveAlertsBlock extends StatelessWidget {
  final bool loading;
  final _FinanzasDashboardSummary summary;

  const _ExecutiveAlertsBlock({required this.loading, required this.summary});

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DashboardSectionHeading(
            title: 'Alertas ejecutivas',
            subtitle:
                'Señales rápidas para atender tensión de caja, pasivo sensible y compras incompletas.',
          ),
          const SizedBox(height: 14),
          if (!loading && summary.executiveAlerts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _MiniInsightCard(
                accent: summary.executiveAlerts.first.tone,
                title: 'Foco principal',
                ringValue: (summary.executiveAlerts.length / 5).clamp(0.0, 1.0),
                ringLabel: '${summary.executiveAlerts.length}',
                primary: summary.executiveAlerts.first.title,
                secondary: 'alertas activas',
              ),
            ),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (summary.executiveAlerts.isEmpty)
            const _DashboardEmptyState(
              icon: Icons.notifications_active_outlined,
              title: 'Sin alertas críticas',
              subtitle:
                  'Cuando exista tensión real de caja o compras sin formalizar aparecerán aquí como foco ejecutivo.',
            )
          else
            Column(
              children: summary.executiveAlerts
                  .map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AlertRow(row: row),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _DashboardSectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;

  const _DashboardSectionHeading({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: tokens.onGlass,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: tokens.badgeText,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _HeroStat {
  final String label;
  final String value;

  const _HeroStat({required this.label, required this.value});
}

class _InsightHeroCard extends StatelessWidget {
  final Color accent;
  final double ringValue;
  final String ringLabel;
  final String ringCaption;
  final String title;
  final String subtitle;
  final List<_HeroStat> stats;

  const _InsightHeroCard({
    required this.accent,
    required this.ringValue,
    required this.ringLabel,
    required this.ringCaption,
    required this.title,
    required this.subtitle,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: tokens.fieldSurface.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tokens.border.withValues(alpha: 0.70)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final ring = _InsightRing(
            value: ringValue,
            accent: accent,
            label: ringLabel,
            caption: ringCaption,
          );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: tokens.onGlass,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  color: tokens.badgeText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: stats
                    .map(
                      (row) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.label,
                            style: TextStyle(
                              color: tokens.badgeText,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            row.value,
                            style: TextStyle(
                              color: tokens.onGlass,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [ring, const SizedBox(height: 16), details],
            );
          }
          return Row(
            children: [
              ring,
              const SizedBox(width: 22),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}

class _MiniInsightCard extends StatelessWidget {
  final Color accent;
  final String title;
  final double ringValue;
  final String ringLabel;
  final String primary;
  final String secondary;

  const _MiniInsightCard({
    required this.accent,
    required this.title,
    required this.ringValue,
    required this.ringLabel,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: tokens.fieldSurface.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.border.withValues(alpha: 0.68)),
      ),
      child: Row(
        children: [
          _InsightRing(
            value: ringValue,
            accent: accent,
            label: ringLabel,
            caption: 'share',
            size: 94,
            strokeWidth: 11,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: tokens.badgeText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  primary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.onGlass,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  secondary,
                  style: TextStyle(
                    color: tokens.badgeText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

class _InsightRing extends StatelessWidget {
  final double value;
  final Color accent;
  final String label;
  final String caption;
  final double size;
  final double strokeWidth;

  const _InsightRing({
    required this.value,
    required this.accent,
    required this.label,
    required this.caption,
    this.size = 132,
    this.strokeWidth = 16,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: strokeWidth,
              color: tokens.badgeBackground.withValues(alpha: 0.56),
            ),
          ),
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: value.clamp(0.0, 1.0),
              strokeWidth: strokeWidth,
              color: accent,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: tokens.onGlass,
                  fontSize: size >= 120 ? 20 : 16,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                caption,
                style: TextStyle(
                  color: tokens.badgeText,
                  fontSize: size >= 120 ? 12 : 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniPeriodBadge extends StatelessWidget {
  final String label;
  final Color accent;

  const _MiniPeriodBadge({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RefreshBadge extends StatelessWidget {
  final Future<void> Function() onTap;

  const _RefreshBadge({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: tokens.fieldSurface.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: tokens.border.withValues(alpha: 0.60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh_rounded, size: 14, color: tokens.badgeText),
            const SizedBox(width: 6),
            Text(
              'Actualizar',
              style: TextStyle(
                color: tokens.badgeText,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanzasDueNotificationDialog extends StatefulWidget {
  final FinanzasDueAlertsSummary summary;
  final List<FinanzasDueAlertItem> visibleItems;
  final Future<void> Function() onOpenPaymentCenter;

  const _FinanzasDueNotificationDialog({
    required this.summary,
    required this.visibleItems,
    required this.onOpenPaymentCenter,
  });

  @override
  State<_FinanzasDueNotificationDialog> createState() =>
      _FinanzasDueNotificationDialogState();
}

class _FinanzasDueNotificationDialogState
    extends State<_FinanzasDueNotificationDialog> {
  final ScrollController _commitmentsScrollController = ScrollController();

  @override
  void dispose() {
    _commitmentsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryItem = widget.visibleItems.first;
    final agreementItems = widget.visibleItems
        .where((item) => item.sourceType == 'CONVENIO')
        .toList(growable: false);
    final invoiceItems = widget.visibleItems
        .where((item) => item.sourceType == 'FACTURA')
        .toList(growable: false);
    final fixedPaymentItems = widget.visibleItems
        .where((item) => item.sourceType == 'PAGO_FIJO')
        .toList(growable: false);
    final accent = switch (primaryItem.severity) {
      FinanzasDueAlertSeverity.critical => kFinanzasCoral,
      FinanzasDueAlertSeverity.warning => kFinanzasAmber,
      FinanzasDueAlertSeverity.info => kFinanzasCopper,
    };
    final commitmentsListMaxHeight = MediaQuery.of(context).size.height * 0.38;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                color: const Color(0xFF10264A).withValues(alpha: 0.96),
                border: Border.all(color: accent.withValues(alpha: 0.42)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 34,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
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
                          color: accent.withValues(alpha: 0.16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.24),
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
                              _finanzasDueDialogHeadline(widget.summary),
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
                      _FinanzasNotificationPill(
                        label: 'Hoy: ${widget.summary.dueTodayCount}',
                      ),
                      _FinanzasNotificationPill(
                        label: '2 días: ${widget.summary.dueIn2DaysCount}',
                      ),
                      _FinanzasNotificationPill(
                        label: '1 semana: ${widget.summary.dueIn7DaysCount}',
                      ),
                      _FinanzasNotificationPill(
                        label:
                            'Monto: ${formatMoney(widget.summary.totalAmount)}',
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
                          'Compromisos prioritarios por origen',
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
                                  if (agreementItems.isNotEmpty)
                                    _FinanzasDueNotificationSection(
                                      title: 'Convenios por vencer',
                                      items: agreementItems,
                                      accent: accent,
                                    ),
                                  if (invoiceItems.isNotEmpty) ...[
                                    if (agreementItems.isNotEmpty)
                                      const SizedBox(height: 14),
                                    _FinanzasDueNotificationSection(
                                      title: 'Facturas fuera de convenio',
                                      items: invoiceItems,
                                      accent: accent,
                                    ),
                                  ],
                                  if (fixedPaymentItems.isNotEmpty) ...[
                                    if (agreementItems.isNotEmpty ||
                                        invoiceItems.isNotEmpty)
                                      const SizedBox(height: 14),
                                    _FinanzasDueNotificationSection(
                                      title: 'Pagos fijos por vencer',
                                      items: fixedPaymentItems,
                                      accent: accent,
                                    ),
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
                          foregroundColor: Colors.white,
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
                        onPressed: widget.onOpenPaymentCenter,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Abrir pagos'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFEA8F4B),
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
        ),
      ),
    );
  }
}

class _FinanzasDueNotificationSection extends StatelessWidget {
  final String title;
  final List<FinanzasDueAlertItem> items;
  final Color accent;

  const _FinanzasDueNotificationSection({
    required this.title,
    required this.items,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: accent,
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < items.length; index++) ...[
          _FinanzasDueNotificationItemCard(item: items[index], accent: accent),
          if (index != items.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _FinanzasDueNotificationItemCard extends StatelessWidget {
  final FinanzasDueAlertItem item;
  final Color accent;

  const _FinanzasDueNotificationItemCard({
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
            _finanzasAlertSourceLabel(item),
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
              color: Color(0xFFF8EBDD),
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

class _FinanzasNotificationPill extends StatelessWidget {
  final String label;

  const _FinanzasNotificationPill({required this.label});

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

String _finanzasDueDialogHeadline(FinanzasDueAlertsSummary summary) {
  if (summary.dueTodayCount > 0) {
    return 'Hay ${summary.dueTodayCount} pagos que vencen hoy y conviene resolver durante esta jornada.';
  }
  if (summary.dueIn2DaysCount > 0) {
    return 'Hay ${summary.dueIn2DaysCount} compromisos que vencen en 48 horas y ya entraron a foco.';
  }
  return 'Hay ${summary.dueIn7DaysCount} compromisos entrando a la ventana semanal de preparación.';
}

String _finanzasAlertSourceLabel(FinanzasDueAlertItem item) {
  switch (item.sourceType) {
    case 'FACTURA':
      return 'Factura fuera de convenio';
    case 'PAGO_FIJO':
      return 'Pago fijo';
    case 'CONVENIO':
      return 'Convenio activo';
    default:
      return 'Compromiso';
  }
}

class _InlineMetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _InlineMetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: tokens.badgeBackground.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border.withValues(alpha: 0.56)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: tokens.badgeText,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: tokens.onGlass,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final double share;
  final Color accent;
  final String value;
  final String secondary;

  const _BarRow({
    required this.label,
    required this.share,
    required this.accent,
    required this.value,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: tokens.fieldSurface.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.border.withValues(alpha: 0.56)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.onGlass,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                value,
                style: TextStyle(
                  color: tokens.onGlass,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            secondary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.badgeText,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: (share / 100).clamp(0.0, 1.0),
              backgroundColor: tokens.badgeBackground.withValues(alpha: 0.56),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgingBar extends StatelessWidget {
  final _FinanzasDashboardSummary summary;

  const _AgingBar({required this.summary});

  @override
  Widget build(BuildContext context) {
    final total = summary.accountsPayable;
    final overdueFlex = _agingFlex(summary.overdueBalance, total);
    final due7Flex = _agingFlex(summary.dueIn7Days, total);
    final due30Flex = _agingFlex(summary.dueIn30Days, total);
    final futureBalance =
        (summary.accountsPayable -
                summary.overdueBalance -
                summary.dueIn7Days -
                summary.dueIn30Days)
            .clamp(0.0, double.infinity);
    final futureFlex = _agingFlex(futureBalance, total);

    return SizedBox(
      height: 14,
      child: Row(
        children: [
          Expanded(
            flex: overdueFlex,
            child: Container(color: kFinanzasCoral),
          ),
          const SizedBox(width: 3),
          Expanded(
            flex: due7Flex,
            child: Container(color: kFinanzasAmber),
          ),
          const SizedBox(width: 3),
          Expanded(
            flex: due30Flex,
            child: Container(color: kFinanzasCopper),
          ),
          const SizedBox(width: 3),
          Expanded(
            flex: futureFlex,
            child: Container(color: kFinanzasTaupe),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: tokens.badgeText,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final _PaymentSuggestionRow row;

  const _SuggestionRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: tokens.fieldSurface.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.border.withValues(alpha: 0.56)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: row.tone.withValues(alpha: 0.14),
              border: Border.all(color: row.tone.withValues(alpha: 0.28)),
            ),
            child: Icon(row.icon, color: row.tone, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.onGlass,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  row.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.badgeText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatMoney(row.amount),
            style: TextStyle(
              color: tokens.onGlass,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskRow extends StatelessWidget {
  final _ProviderRiskRow row;

  const _RiskRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: tokens.fieldSurface.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.border.withValues(alpha: 0.56)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.providerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.onGlass,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                row.riskLabel,
                style: TextStyle(
                  color: row.riskColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            row.secondary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.badgeText,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: (row.share / 100).clamp(0.0, 1.0),
              backgroundColor: tokens.badgeBackground.withValues(alpha: 0.56),
              valueColor: AlwaysStoppedAnimation<Color>(row.riskColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final _ExecutiveAlertRow row;

  const _AlertRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: tokens.fieldSurface.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: row.tone.withValues(alpha: 0.26)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: row.tone.withValues(alpha: 0.14),
              border: Border.all(color: row.tone.withValues(alpha: 0.28)),
            ),
            child: Icon(row.icon, color: row.tone, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  style: TextStyle(
                    color: tokens.onGlass,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  row.subtitle,
                  style: TextStyle(
                    color: tokens.badgeText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
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

class _DashboardEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _DashboardEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: tokens.primaryStrong),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: tokens.onGlass,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: tokens.badgeText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanzasDashboardHeaderBrand extends StatelessWidget {
  const _FinanzasDashboardHeaderBrand();

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: kFinanzasPanelSurfaceStrong.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kFinanzasBorder.withValues(alpha: 0.92)),
            boxShadow: [
              BoxShadow(
                color: tokens.glow.withValues(alpha: 0.24),
                blurRadius: 28,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(child: DicsaLogoD(size: 40, progress: 1)),
        ),
        const SizedBox(width: 20),
        Text(
          'Dashboard Finanzas',
          maxLines: 1,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.25,
            height: 1.0,
            color: kFinanzasInk,
          ),
        ),
      ],
    );
  }
}

class _FinanzasHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;
  final bool compact;
  final bool iconOnly;
  final int notificationCount;

  const _FinanzasHeaderButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
    this.compact = false,
    this.iconOnly = false,
    this.notificationCount = 0,
  });

  @override
  State<_FinanzasHeaderButton> createState() => _FinanzasHeaderButtonState();
}

class _FinanzasHeaderButtonState extends State<_FinanzasHeaderButton> {
  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final enabled = widget.onTap != null || widget.onTapSync != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          splashColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          onTap: !enabled
              ? null
              : () async {
                  if (widget.onTap != null) {
                    await widget.onTap!();
                  } else {
                    widget.onTapSync?.call();
                  }
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: widget.iconOnly ? 56 : 176,
            height: 56,
            padding: EdgeInsets.symmetric(
              horizontal: widget.iconOnly ? 0 : 20,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  kFinanzasOrange.withValues(alpha: 0.26),
                  kFinanzasOrangeIntense.withValues(alpha: 0.18),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: kFinanzasBorder.withValues(alpha: 0.90),
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 16,
                  color: kFinanzasOrange.withValues(alpha: 0.14),
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  blurRadius: 10,
                  color: tokens.glow.withValues(alpha: 0.05),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                widget.iconOnly
                    ? Center(
                        child: Icon(
                          widget.icon,
                          size: 22,
                          color: tokens.primaryStrong,
                        ),
                      )
                    : Row(
                        children: [
                          Icon(widget.icon, size: 20, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                widget.label,
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
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

class _BankBalanceBreakdown {
  final String accountKey;
  final String company;
  final String branch;
  final double balance;
  final double share;

  const _BankBalanceBreakdown({
    required this.accountKey,
    required this.company,
    required this.branch,
    required this.balance,
    required this.share,
  });

  String get label => '$company · $branch';
}

class _ProviderBalanceBreakdown {
  final String providerId;
  final String providerName;
  final double balance;
  final double overdueAmount;
  final int invoiceCount;
  final double share;

  const _ProviderBalanceBreakdown({
    required this.providerId,
    required this.providerName,
    required this.balance,
    required this.overdueAmount,
    required this.invoiceCount,
    required this.share,
  });

  String get shareLabel => '${share.toStringAsFixed(1)}% del pasivo';
}

class _EffectiveSupplierInvoice {
  final FinanzasSupplierInvoiceRecord source;
  final double effectiveBalanceAmount;
  final String effectiveStatus;

  const _EffectiveSupplierInvoice({
    required this.source,
    required this.effectiveBalanceAmount,
    required this.effectiveStatus,
  });
}

class _PaymentSuggestionRow {
  final String title;
  final String subtitle;
  final double amount;
  final IconData icon;
  final Color tone;
  final int score;

  const _PaymentSuggestionRow({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.icon,
    required this.tone,
    required this.score,
  });
}

class _CrossPurchaseRow {
  final String label;
  final double amount;
  final double weight;
  final double share;

  const _CrossPurchaseRow({
    required this.label,
    required this.amount,
    required this.weight,
    required this.share,
  });
}

class _ProviderRiskRow {
  final String providerName;
  final double share;
  final String shareLabel;
  final String secondary;
  final String riskLabel;
  final Color riskColor;
  final int score;

  const _ProviderRiskRow({
    required this.providerName,
    required this.share,
    required this.shareLabel,
    required this.secondary,
    required this.riskLabel,
    required this.riskColor,
    required this.score,
  });
}

class _ExecutiveAlertRow {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tone;
  final int severity;

  const _ExecutiveAlertRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tone,
    required this.severity,
  });
}

class _FinanzasDashboardSummary {
  final double availableBalance;
  final double accountsPayable;
  final double overdueBalance;
  final double dueIn7Days;
  final double dueIn30Days;
  final double monthCommitments;
  final double monthSupplierCommitments;
  final double monthFixedCommitments;
  final double openClientCollections;
  final double shortTermCommitments;
  final double projectedNetFlow;
  final int openInvoiceCount;
  final int overdueInvoiceCount;
  final String availableDetail;
  final String monthCommitmentsDetail;
  final String projectedNetFlowDetail;
  final String cashPressureLabel;
  final String cashPressureDetail;
  final Color cashPressureAccent;
  final double shortTermCoverageProgress;
  final String shortTermCoverageLabel;
  final List<_BankBalanceBreakdown> bankBalances;
  final List<_ProviderBalanceBreakdown> providerBalances;
  final double executedPaymentsMonth;
  final double pendingPaymentsMonth;
  final double fixedExecutedMonthAmount;
  final double fixedPendingMonthAmount;
  final int activeAgreementCount;
  final int delayedAgreementCount;
  final int criticalInvoiceCount;
  final String leadingProviderLabel;
  final List<_PaymentSuggestionRow> paymentSuggestions;
  final List<_ProviderRiskRow> providerRiskRows;
  final double monthPurchaseAmount;
  final double monthPurchaseWeight;
  final int noInvoiceTicketCount;
  final int pendingPaymentTicketCount;
  final List<_CrossPurchaseRow> purchaseProviderRows;
  final List<_CrossPurchaseRow> purchaseMaterialRows;
  final FinanzasDueAlertsSummary dueAlerts;
  final List<_ExecutiveAlertRow> executiveAlerts;

  const _FinanzasDashboardSummary({
    required this.availableBalance,
    required this.accountsPayable,
    required this.overdueBalance,
    required this.dueIn7Days,
    required this.dueIn30Days,
    required this.monthCommitments,
    required this.monthSupplierCommitments,
    required this.monthFixedCommitments,
    required this.openClientCollections,
    required this.shortTermCommitments,
    required this.projectedNetFlow,
    required this.openInvoiceCount,
    required this.overdueInvoiceCount,
    required this.availableDetail,
    required this.monthCommitmentsDetail,
    required this.projectedNetFlowDetail,
    required this.cashPressureLabel,
    required this.cashPressureDetail,
    required this.cashPressureAccent,
    required this.shortTermCoverageProgress,
    required this.shortTermCoverageLabel,
    required this.bankBalances,
    required this.providerBalances,
    required this.executedPaymentsMonth,
    required this.pendingPaymentsMonth,
    required this.fixedExecutedMonthAmount,
    required this.fixedPendingMonthAmount,
    required this.activeAgreementCount,
    required this.delayedAgreementCount,
    required this.criticalInvoiceCount,
    required this.leadingProviderLabel,
    required this.paymentSuggestions,
    required this.providerRiskRows,
    required this.monthPurchaseAmount,
    required this.monthPurchaseWeight,
    required this.noInvoiceTicketCount,
    required this.pendingPaymentTicketCount,
    required this.purchaseProviderRows,
    required this.purchaseMaterialRows,
    required this.dueAlerts,
    required this.executiveAlerts,
  });

  const _FinanzasDashboardSummary.empty()
    : availableBalance = 0,
      accountsPayable = 0,
      overdueBalance = 0,
      dueIn7Days = 0,
      dueIn30Days = 0,
      monthCommitments = 0,
      monthSupplierCommitments = 0,
      monthFixedCommitments = 0,
      openClientCollections = 0,
      shortTermCommitments = 0,
      projectedNetFlow = 0,
      openInvoiceCount = 0,
      overdueInvoiceCount = 0,
      availableDetail = 'Sin movimientos todavía',
      monthCommitmentsDetail = 'Sin compromisos detectados',
      projectedNetFlowDetail = 'Sin base de corto plazo',
      cashPressureLabel = 'Baja',
      cashPressureDetail = 'Sin presión visible',
      cashPressureAccent = kFinanzasSage,
      shortTermCoverageProgress = 0,
      shortTermCoverageLabel = 'Sin presión',
      bankBalances = const <_BankBalanceBreakdown>[],
      providerBalances = const <_ProviderBalanceBreakdown>[],
      executedPaymentsMonth = 0,
      pendingPaymentsMonth = 0,
      fixedExecutedMonthAmount = 0,
      fixedPendingMonthAmount = 0,
      activeAgreementCount = 0,
      delayedAgreementCount = 0,
      criticalInvoiceCount = 0,
      leadingProviderLabel = 'Sin base',
      paymentSuggestions = const <_PaymentSuggestionRow>[],
      providerRiskRows = const <_ProviderRiskRow>[],
      monthPurchaseAmount = 0,
      monthPurchaseWeight = 0,
      noInvoiceTicketCount = 0,
      pendingPaymentTicketCount = 0,
      purchaseProviderRows = const <_CrossPurchaseRow>[],
      purchaseMaterialRows = const <_CrossPurchaseRow>[],
      dueAlerts = const FinanzasDueAlertsSummary.empty(),
      executiveAlerts = const <_ExecutiveAlertRow>[];
}

_FinanzasDashboardSummary _buildFinanzasDashboardSummary({
  required List<FinanzasBankMovementRecord> movements,
  required List<FinanzasClientPaymentAccountRecord> openClientAccounts,
  required List<FinanzasSupplierInvoiceRecord> invoices,
  required List<FinanzasFixedPaymentRecord> fixedPayments,
  required List<FinanzasSupplierAgreementRecord> agreements,
  required FinanzasDueAlertsSummary dueAlerts,
  required List<ComprasTicketRecord> tickets,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final currentMonthStart = DateTime(today.year, today.month);
  final nextMonthStart = DateTime(today.year, today.month + 1);
  final next7 = today.add(const Duration(days: 7));
  final next30 = today.add(const Duration(days: 30));

  double availableBalance = 0;
  double previousClosingBalance = 0;
  final bankAccumulator = <String, _MutableBankBalance>{};
  for (final row in movements) {
    final signed = row.creditAmount - row.debitAmount;
    availableBalance += signed;
    if (row.date.isBefore(currentMonthStart)) {
      previousClosingBalance += signed;
    }
    final existing =
        bankAccumulator[row.accountKey] ??
        _MutableBankBalance(company: row.company, branch: row.branch);
    existing.balance += signed;
    bankAccumulator[row.accountKey] = existing;
  }

  final effectiveInvoices = _buildEffectiveSupplierInvoices(
    invoices: invoices,
    movements: movements,
    today: today,
  );
  final openInvoices = effectiveInvoices
      .where((row) => row.effectiveBalanceAmount > 0.009)
      .toList(growable: false);
  final accountsPayable = openInvoices.fold<double>(
    0,
    (sum, row) => sum + row.effectiveBalanceAmount,
  );

  double overdueBalance = 0;
  int overdueInvoiceCount = 0;
  double dueIn7Days = 0;
  double dueIn30Days = 0;
  double monthSupplierCommitments = 0;
  final providerAccumulator = <String, _MutableProviderBalance>{};

  for (final invoice in openInvoices) {
    final dueDate = invoice.source.dueDate;
    final providerKey = normalizeFinanzasCompanyAliasKey(
      invoice.source.providerNameSnapshot,
    );
    final provider =
        providerAccumulator[providerKey] ??
        _MutableProviderBalance(name: invoice.source.providerNameSnapshot);
    provider.balance += invoice.effectiveBalanceAmount;
    provider.invoiceCount += 1;

    if (dueDate != null) {
      final normalizedDue = DateTime(dueDate.year, dueDate.month, dueDate.day);
      if (normalizedDue.isBefore(today)) {
        overdueBalance += invoice.effectiveBalanceAmount;
        overdueInvoiceCount += 1;
        provider.overdueAmount += invoice.effectiveBalanceAmount;
      } else if (!normalizedDue.isAfter(next7)) {
        dueIn7Days += invoice.effectiveBalanceAmount;
      } else if (!normalizedDue.isAfter(next30)) {
        dueIn30Days += invoice.effectiveBalanceAmount;
      }
      if (!normalizedDue.isBefore(currentMonthStart) &&
          normalizedDue.isBefore(nextMonthStart)) {
        monthSupplierCommitments += invoice.effectiveBalanceAmount;
      }
    }
    providerAccumulator[providerKey] = provider;
  }

  double monthFixedCommitments = 0;
  double next7FixedCommitments = 0;
  double fixedExecutedMonthAmount = 0;
  double fixedPendingMonthAmount = 0;
  for (final payment in fixedPayments) {
    final paymentDate = DateTime(
      payment.paymentDate.year,
      payment.paymentDate.month,
      payment.paymentDate.day,
    );
    final inCurrentMonth =
        !paymentDate.isBefore(currentMonthStart) &&
        paymentDate.isBefore(nextMonthStart);
    if (payment.status == 'PAGADO') {
      if (inCurrentMonth) {
        fixedExecutedMonthAmount += payment.amount;
      }
      continue;
    }
    if (inCurrentMonth) {
      fixedPendingMonthAmount += payment.amount;
    }
    if (!paymentDate.isBefore(currentMonthStart) &&
        paymentDate.isBefore(nextMonthStart)) {
      monthFixedCommitments += payment.amount;
    }
    if (!paymentDate.isBefore(today) && !paymentDate.isAfter(next7)) {
      next7FixedCommitments += payment.amount;
    }
  }

  final monthCommitments = monthSupplierCommitments + monthFixedCommitments;
  final executedPaymentsMonth = movements
      .where((row) {
        final movementDate = DateTime(
          row.date.year,
          row.date.month,
          row.date.day,
        );
        return !movementDate.isBefore(currentMonthStart) &&
            movementDate.isBefore(nextMonthStart) &&
            row.debitAmount > 0.009 &&
            (row.linkedSupplierInvoiceId != null ||
                row.linkedFixedPaymentId != null);
      })
      .fold<double>(
        0,
        (sum, row) =>
            sum +
            (row.hasLinkedSupplierInvoice
                ? row.effectiveSupplierAppliedAmount
                : row.debitAmount),
      );
  final pendingPaymentsMonth = (monthCommitments - executedPaymentsMonth).clamp(
    0.0,
    double.infinity,
  );
  final openClientCollections = openClientAccounts.fold<double>(
    0,
    (sum, row) => sum + row.pendingBalance,
  );
  final shortTermCommitments =
      overdueBalance + dueIn7Days + next7FixedCommitments;
  final projectedNetFlow = openClientCollections - shortTermCommitments;
  final coverageRatio = shortTermCommitments <= 0.009
      ? 2.0
      : availableBalance / shortTermCommitments;

  late final String cashPressureLabel;
  late final String cashPressureDetail;
  late final Color cashPressureAccent;
  if (shortTermCommitments <= 0.009) {
    cashPressureLabel = 'Baja';
    cashPressureDetail = 'Sin urgencias inmediatas visibles';
    cashPressureAccent = kFinanzasSage;
  } else if (coverageRatio < 1) {
    cashPressureLabel = 'Alta';
    cashPressureDetail = 'La caja no cubre el frente inmediato';
    cashPressureAccent = kFinanzasCoral;
  } else if (coverageRatio < 1.4) {
    cashPressureLabel = 'Media';
    cashPressureDetail = 'La caja cubre con margen corto';
    cashPressureAccent = kFinanzasAmber;
  } else {
    cashPressureLabel = 'Baja';
    cashPressureDetail = 'La caja soporta el frente inmediato';
    cashPressureAccent = kFinanzasSage;
  }

  final totalBankBalanceMagnitude = bankAccumulator.values.fold<double>(
    0,
    (sum, row) => sum + row.balance.abs(),
  );
  final bankBalances =
      bankAccumulator.entries
          .map(
            (entry) => _BankBalanceBreakdown(
              accountKey: entry.key,
              company: entry.value.company,
              branch: entry.value.branch,
              balance: entry.value.balance,
              share: totalBankBalanceMagnitude <= 0.009
                  ? 0
                  : (entry.value.balance.abs() / totalBankBalanceMagnitude) *
                        100,
            ),
          )
          .where((row) => row.balance.abs() > 0.009)
          .toList(growable: false)
        ..sort((a, b) => b.balance.compareTo(a.balance));

  final providerBalances =
      providerAccumulator.entries
          .map(
            (entry) => _ProviderBalanceBreakdown(
              providerId: entry.key,
              providerName: entry.value.name,
              balance: entry.value.balance,
              overdueAmount: entry.value.overdueAmount,
              invoiceCount: entry.value.invoiceCount,
              share: accountsPayable <= 0.009
                  ? 0
                  : (entry.value.balance / accountsPayable) * 100,
            ),
          )
          .toList(growable: false)
        ..sort((a, b) => b.balance.compareTo(a.balance));

  final activeAgreementCount = agreements
      .where(
        (row) =>
            row.status == 'ACTIVO' ||
            row.status == 'CUMPLIDO' ||
            row.status == 'ATRASADO',
      )
      .length;
  final delayedAgreementCount = agreements
      .where((row) => row.status == 'ATRASADO')
      .length;
  final criticalInvoiceCount = openInvoices
      .where((row) => row.source.manualPriority == 'CRITICA')
      .length;
  final leadingProviderLabel = providerBalances.isEmpty
      ? 'Sin base'
      : providerBalances.first.providerName;
  final paymentSuggestions = _buildPaymentSuggestions(
    invoices: openInvoices,
    fixedPayments: fixedPayments,
    today: today,
  );
  final providerRiskRows = _buildProviderRiskRows(
    providerBalances: providerBalances,
    agreements: agreements,
  );
  final monthTickets = tickets
      .where((row) {
        final ticketDate = DateTime(
          row.date.year,
          row.date.month,
          row.date.day,
        );
        return !ticketDate.isBefore(currentMonthStart) &&
            ticketDate.isBefore(nextMonthStart);
      })
      .toList(growable: false);
  final monthPurchaseAmount = monthTickets.fold<double>(
    0,
    (sum, row) => sum + row.amount,
  );
  final monthPurchaseWeight = monthTickets.fold<double>(
    0,
    (sum, row) => sum + row.payableWeight,
  );
  final noInvoiceTicketCount = monthTickets
      .where((row) => row.facturaStatus != 'FACTURADO')
      .length;
  final pendingPaymentTicketCount = monthTickets
      .where((row) => row.pagoStatus != 'PAGADO')
      .length;
  final purchaseProviderRows = _buildCrossPurchaseRows(
    tickets: monthTickets,
    groupByProvider: true,
  );
  final purchaseMaterialRows = _buildCrossPurchaseRows(
    tickets: monthTickets,
    groupByProvider: false,
  );
  final executiveAlerts = _buildExecutiveAlerts(
    availableBalance: availableBalance,
    shortTermCommitments: shortTermCommitments,
    overdueBalance: overdueBalance,
    dueAlerts: dueAlerts,
    delayedAgreementCount: delayedAgreementCount,
    noInvoiceTicketCount: noInvoiceTicketCount,
    pendingPaymentTicketCount: pendingPaymentTicketCount,
    monthPurchaseAmount: monthPurchaseAmount,
    providerBalances: providerBalances,
  );

  final deltaBalance = availableBalance - previousClosingBalance;
  final availableDetail = previousClosingBalance.abs() <= 0.009
      ? 'Sin cierre previo base para comparar'
      : '${deltaBalance >= 0 ? '+' : '-'}${formatMoney(deltaBalance.abs())} vs cierre del mes anterior';
  final monthCommitmentsDetail =
      '${formatMoney(monthSupplierCommitments)} proveedores + ${formatMoney(monthFixedCommitments)} pagos fijos';
  final projectedNetFlowDetail =
      '${formatMoney(openClientCollections)} cobros abiertos contra ${formatMoney(shortTermCommitments)} urgencias de corto plazo';

  return _FinanzasDashboardSummary(
    availableBalance: availableBalance,
    accountsPayable: accountsPayable,
    overdueBalance: overdueBalance,
    dueIn7Days: dueIn7Days,
    dueIn30Days: dueIn30Days,
    monthCommitments: monthCommitments,
    monthSupplierCommitments: monthSupplierCommitments,
    monthFixedCommitments: monthFixedCommitments,
    openClientCollections: openClientCollections,
    shortTermCommitments: shortTermCommitments,
    projectedNetFlow: projectedNetFlow,
    openInvoiceCount: openInvoices.length,
    overdueInvoiceCount: overdueInvoiceCount,
    availableDetail: availableDetail,
    monthCommitmentsDetail: monthCommitmentsDetail,
    projectedNetFlowDetail: projectedNetFlowDetail,
    cashPressureLabel: cashPressureLabel,
    cashPressureDetail: cashPressureDetail,
    cashPressureAccent: cashPressureAccent,
    shortTermCoverageProgress: shortTermCommitments <= 0.009
        ? 1
        : (availableBalance / shortTermCommitments).clamp(0.0, 1.0),
    shortTermCoverageLabel: shortTermCommitments <= 0.009
        ? 'Sin compromiso inmediato'
        : '${coverageRatio.toStringAsFixed(2)}x cobertura',
    bankBalances: bankBalances,
    providerBalances: providerBalances,
    executedPaymentsMonth: executedPaymentsMonth,
    pendingPaymentsMonth: pendingPaymentsMonth,
    fixedExecutedMonthAmount: fixedExecutedMonthAmount,
    fixedPendingMonthAmount: fixedPendingMonthAmount,
    activeAgreementCount: activeAgreementCount,
    delayedAgreementCount: delayedAgreementCount,
    criticalInvoiceCount: criticalInvoiceCount,
    leadingProviderLabel: leadingProviderLabel,
    paymentSuggestions: paymentSuggestions,
    providerRiskRows: providerRiskRows,
    monthPurchaseAmount: monthPurchaseAmount,
    monthPurchaseWeight: monthPurchaseWeight,
    noInvoiceTicketCount: noInvoiceTicketCount,
    pendingPaymentTicketCount: pendingPaymentTicketCount,
    purchaseProviderRows: purchaseProviderRows,
    purchaseMaterialRows: purchaseMaterialRows,
    dueAlerts: dueAlerts,
    executiveAlerts: executiveAlerts,
  );
}

class _MutableBankBalance {
  final String company;
  final String branch;
  double balance = 0;

  _MutableBankBalance({required this.company, required this.branch});
}

class _MutableProviderBalance {
  final String name;
  double balance = 0;
  double overdueAmount = 0;
  int invoiceCount = 0;

  _MutableProviderBalance({required this.name});
}

int _agingFlex(double value, double total) {
  if (total <= 0.009 || value <= 0.009) return 1;
  return (value / total * 100).round().clamp(1, 100);
}

List<_PaymentSuggestionRow> _buildPaymentSuggestions({
  required List<_EffectiveSupplierInvoice> invoices,
  required List<FinanzasFixedPaymentRecord> fixedPayments,
  required DateTime today,
}) {
  final suggestions = <_PaymentSuggestionRow>[];
  final weekLimit = today.add(const Duration(days: 7));
  for (final invoice in invoices) {
    var score = 0;
    final dueDate = invoice.source.dueDate;
    if (dueDate != null) {
      final dueOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
      if (dueOnly.isBefore(today)) {
        score += 100;
      } else if (!dueOnly.isAfter(today)) {
        score += 80;
      } else if (!dueOnly.isAfter(weekLimit)) {
        score += 45;
      }
    } else {
      score += 12;
    }
    if (invoice.source.manualPriority == 'CRITICA') {
      score += 110;
    } else if (invoice.source.manualPriority == 'ALTA') {
      score += 60;
    }
    if (invoice.effectiveStatus == 'CONVENIO' ||
        invoice.source.status == 'CONVENIO') {
      score += 16;
    }
    if (invoice.effectiveBalanceAmount >= 100000) {
      score += 16;
    } else if (invoice.effectiveBalanceAmount >= 25000) {
      score += 8;
    }
    if (score <= 0) continue;
    suggestions.add(
      _PaymentSuggestionRow(
        title: invoice.source.providerNameSnapshot,
        subtitle:
            'Factura ${invoice.source.folio.isEmpty ? 'sin folio' : invoice.source.folio} · ${_priorityLabel(invoice.source.manualPriority)} · ${invoice.source.dueDate == null ? 'sin vencimiento' : 'vence ${invoice.source.dueDate!.day.toString().padLeft(2, '0')}/${invoice.source.dueDate!.month.toString().padLeft(2, '0')}'}',
        amount: invoice.effectiveBalanceAmount,
        icon: Icons.receipt_long_outlined,
        tone: invoice.source.manualPriority == 'CRITICA'
            ? kFinanzasCoral
            : invoice.source.manualPriority == 'ALTA'
            ? kFinanzasAmber
            : kFinanzasCopper,
        score: score,
      ),
    );
  }
  for (final payment in fixedPayments.where((row) => row.status != 'PAGADO')) {
    var score = 10;
    final dueOnly = DateTime(
      payment.paymentDate.year,
      payment.paymentDate.month,
      payment.paymentDate.day,
    );
    if (dueOnly.isBefore(today)) {
      score += 90;
    } else if (!dueOnly.isAfter(today)) {
      score += 70;
    } else if (!dueOnly.isAfter(weekLimit)) {
      score += 40;
    }
    suggestions.add(
      _PaymentSuggestionRow(
        title: payment.companyNameSnapshot,
        subtitle:
            'Pago fijo · ${finFixedPaymentStatusLabel(payment.status)} · vence ${dueOnly.day.toString().padLeft(2, '0')}/${dueOnly.month.toString().padLeft(2, '0')}',
        amount: payment.amount,
        icon: Icons.event_note_rounded,
        tone: dueOnly.isBefore(today) ? kFinanzasCoral : kFinanzasAmber,
        score: score,
      ),
    );
  }
  suggestions.sort((a, b) => b.score.compareTo(a.score));
  return suggestions;
}

List<_EffectiveSupplierInvoice> _buildEffectiveSupplierInvoices({
  required List<FinanzasSupplierInvoiceRecord> invoices,
  required List<FinanzasBankMovementRecord> movements,
  required DateTime today,
}) {
  final debitByInvoiceId = <String, double>{};
  for (final row in movements) {
    final invoiceId = row.linkedSupplierInvoiceId;
    if (invoiceId == null || invoiceId.isEmpty) continue;
    final applied = row.effectiveSupplierAppliedAmount > 0.009
        ? row.effectiveSupplierAppliedAmount
        : 0.0;
    if (applied <= 0.009) continue;
    debitByInvoiceId.update(
      invoiceId,
      (sum) => sum + applied,
      ifAbsent: () => applied,
    );
  }
  return invoices
      .map((invoice) {
        final linkedPaid = debitByInvoiceId[invoice.id];
        final effectiveBalance = linkedPaid == null
            ? invoice.balanceAmount.clamp(0.0, invoice.totalAmount).toDouble()
            : (invoice.totalAmount - linkedPaid)
                  .clamp(0.0, invoice.totalAmount)
                  .toDouble();
        final effectiveStatus =
            invoice.status == 'CONVENIO' && effectiveBalance > 0.009
            ? 'CONVENIO'
            : deriveSupplierInvoiceStatus(
                balanceAmount: effectiveBalance,
                dueDate: invoice.dueDate,
                today: today,
              );
        return _EffectiveSupplierInvoice(
          source: invoice,
          effectiveBalanceAmount: effectiveBalance,
          effectiveStatus: effectiveStatus,
        );
      })
      .toList(growable: false);
}

List<_ProviderRiskRow> _buildProviderRiskRows({
  required List<_ProviderBalanceBreakdown> providerBalances,
  required List<FinanzasSupplierAgreementRecord> agreements,
}) {
  final delayedByProvider = <String, int>{};
  final activeByProvider = <String, int>{};
  for (final agreement in agreements) {
    if (agreement.status == 'CANCELADO') continue;
    final providerKey = normalizeFinanzasCompanyAliasKey(
      agreement.providerNameSnapshot,
    );
    activeByProvider.update(
      providerKey,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
    if (agreement.status == 'ATRASADO') {
      delayedByProvider.update(
        providerKey,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
  }
  final rows =
      providerBalances
          .map((row) {
            final delayed = delayedByProvider[row.providerId] ?? 0;
            final active = activeByProvider[row.providerId] ?? 0;
            final riskScore =
                row.share.round() +
                (row.overdueAmount > 0.009 ? 35 : 0) +
                (delayed * 20) +
                (active * 6);
            final riskLabel = riskScore >= 90
                ? 'Riesgo alto'
                : riskScore >= 55
                ? 'Riesgo medio'
                : 'Seguimiento';
            final riskColor = riskScore >= 90
                ? kFinanzasCoral
                : riskScore >= 55
                ? kFinanzasAmber
                : kFinanzasCopper;
            final fragments = <String>[
              row.shareLabel,
              if (row.overdueAmount > 0.009)
                '${formatMoney(row.overdueAmount)} vencidos',
              if (active > 0) '$active convenios',
              if (delayed > 0) '$delayed atrasados',
            ];
            return _ProviderRiskRow(
              providerName: row.providerName,
              share: row.share,
              shareLabel: row.shareLabel,
              secondary: fragments.join(' · '),
              riskLabel: riskLabel,
              riskColor: riskColor,
              score: riskScore,
            );
          })
          .toList(growable: false)
        ..sort((a, b) => b.score.compareTo(a.score));
  return rows;
}

List<_CrossPurchaseRow> _buildCrossPurchaseRows({
  required List<ComprasTicketRecord> tickets,
  required bool groupByProvider,
}) {
  final buckets = <String, (String label, double amount, double weight)>{};
  for (final row in tickets) {
    final key = groupByProvider ? row.providerId : row.materialId;
    final label = groupByProvider
        ? row.providerNameSnapshot
        : row.materialNameSnapshot;
    final current = buckets[key];
    if (current == null) {
      buckets[key] = (label, row.amount, row.payableWeight);
    } else {
      buckets[key] = (
        current.$1,
        current.$2 + row.amount,
        current.$3 + row.payableWeight,
      );
    }
  }
  final totalAmount = buckets.values.fold<double>(
    0,
    (sum, row) => sum + row.$2,
  );
  final rows =
      buckets.values
          .map(
            (row) => _CrossPurchaseRow(
              label: row.$1,
              amount: row.$2,
              weight: row.$3,
              share: totalAmount <= 0.009 ? 0 : (row.$2 / totalAmount) * 100,
            ),
          )
          .toList(growable: false)
        ..sort((a, b) => b.amount.compareTo(a.amount));
  return rows;
}

List<_ExecutiveAlertRow> _buildExecutiveAlerts({
  required double availableBalance,
  required double shortTermCommitments,
  required double overdueBalance,
  required FinanzasDueAlertsSummary dueAlerts,
  required int delayedAgreementCount,
  required int noInvoiceTicketCount,
  required int pendingPaymentTicketCount,
  required double monthPurchaseAmount,
  required List<_ProviderBalanceBreakdown> providerBalances,
}) {
  final alerts = <_ExecutiveAlertRow>[];
  if (dueAlerts.overdueCount > 0) {
    alerts.add(
      _ExecutiveAlertRow(
        title: 'Vencimientos ya fuera de tiempo',
        subtitle:
            '${dueAlerts.overdueCount} compromisos por ${formatMoney(dueAlerts.overdueAmount)} ya están vencidos en finanzas.',
        icon: Icons.notifications_active_rounded,
        tone: kFinanzasCoral,
        severity: 98,
      ),
    );
  }
  if (dueAlerts.dueTodayCount > 0) {
    alerts.add(
      _ExecutiveAlertRow(
        title: 'Pagos que vencen hoy',
        subtitle:
            '${dueAlerts.dueTodayCount} compromisos por ${formatMoney(dueAlerts.dueTodayAmount)} vencen hoy y requieren salida inmediata.',
        icon: Icons.today_rounded,
        tone: kFinanzasCoral,
        severity: 94,
      ),
    );
  }
  if (dueAlerts.dueIn2DaysCount > 0) {
    alerts.add(
      _ExecutiveAlertRow(
        title: 'Recordatorio a 2 días',
        subtitle:
            '${dueAlerts.dueIn2DaysCount} compromisos por ${formatMoney(dueAlerts.dueIn2DaysAmount)} vencerán en 48 horas.',
        icon: Icons.event_repeat_rounded,
        tone: kFinanzasAmber,
        severity: 86,
      ),
    );
  }
  if (dueAlerts.dueIn7DaysCount > 0) {
    alerts.add(
      _ExecutiveAlertRow(
        title: 'Ventana de preparación semanal',
        subtitle:
            '${dueAlerts.dueIn7DaysCount} compromisos por ${formatMoney(dueAlerts.dueIn7DaysAmount)} vencen en una semana.',
        icon: Icons.date_range_rounded,
        tone: kFinanzasCopper,
        severity: 76,
      ),
    );
  }
  if (shortTermCommitments > 0.009 && availableBalance < shortTermCommitments) {
    alerts.add(
      _ExecutiveAlertRow(
        title: 'Caja insuficiente frente al frente inmediato',
        subtitle:
            '${formatMoney(availableBalance)} disponibles contra ${formatMoney(shortTermCommitments)} comprometidos a corto plazo.',
        icon: Icons.warning_amber_rounded,
        tone: kFinanzasCoral,
        severity: 100,
      ),
    );
  }
  if (overdueBalance > 0.009) {
    alerts.add(
      _ExecutiveAlertRow(
        title: 'Pasivo vencido relevante',
        subtitle:
            '${formatMoney(overdueBalance)} ya está fuera de tiempo y requiere atención prioritaria.',
        icon: Icons.schedule_send_rounded,
        tone: kFinanzasAmber,
        severity: 90,
      ),
    );
  }
  if (delayedAgreementCount > 0) {
    alerts.add(
      _ExecutiveAlertRow(
        title: 'Convenios con atraso',
        subtitle:
            '$delayedAgreementCount convenios muestran estatus atrasado y pueden tensionar la relación con proveedor.',
        icon: Icons.handshake_outlined,
        tone: kFinanzasAmber,
        severity: 80,
      ),
    );
  }
  if (noInvoiceTicketCount > 0) {
    alerts.add(
      _ExecutiveAlertRow(
        title: 'Compras sin formalizar en factura',
        subtitle:
            '$noInvoiceTicketCount tickets del mes siguen sin factura y todavía no consolidan bien el pasivo operativo.',
        icon: Icons.receipt_outlined,
        tone: kFinanzasCopper,
        severity: 72,
      ),
    );
  }
  if (pendingPaymentTicketCount > 0) {
    alerts.add(
      _ExecutiveAlertRow(
        title: 'Tickets con presión de pago abierta',
        subtitle:
            '$pendingPaymentTicketCount tickets del mes siguen pendientes de pago y aún cargan flujo financiero.',
        icon: Icons.payments_outlined,
        tone: kFinanzasCopper,
        severity: 68,
      ),
    );
  }
  if (providerBalances.isNotEmpty && providerBalances.first.share >= 45) {
    alerts.add(
      _ExecutiveAlertRow(
        title: 'Concentración alta en un solo proveedor',
        subtitle:
            '${providerBalances.first.providerName} concentra ${providerBalances.first.share.toStringAsFixed(1)}% del pasivo abierto.',
        icon: Icons.account_tree_outlined,
        tone: kFinanzasCoral,
        severity: 84,
      ),
    );
  }
  if (monthPurchaseAmount >= 100000) {
    alerts.add(
      _ExecutiveAlertRow(
        title: 'Mes de compra con carga relevante',
        subtitle:
            'Compras del mes por ${formatMoney(monthPurchaseAmount)} ya están presionando lectura financiera y tesorería.',
        icon: Icons.shopping_bag_outlined,
        tone: kFinanzasTaupe,
        severity: 60,
      ),
    );
  }
  alerts.sort((a, b) => b.severity.compareTo(a.severity));
  return alerts.take(5).toList(growable: false);
}

String _priorityLabel(String value) {
  switch (value) {
    case 'CRITICA':
      return 'Critica';
    case 'ALTA':
      return 'Alta';
    default:
      return 'Normal';
  }
}
