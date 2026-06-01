import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/general_dashboard_page.dart';
import '../finanzas/finanzas_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/number_formatters.dart';
import 'compras_area_chrome.dart';
import 'compras_catalog_page.dart';
import 'compras_data_store.dart';
import 'compras_price_adjustments_page.dart';
import 'compras_provider_directory_page.dart';
import 'compras_provider_directory_store.dart';
import 'compras_theme.dart';
import 'compras_tickets_page.dart';
import 'compras_tickets_store.dart';

class ComprasDashboardPage extends StatefulWidget {
  final bool instantOpen;

  const ComprasDashboardPage({super.key, this.instantOpen = false});

  @override
  State<ComprasDashboardPage> createState() => _ComprasDashboardPageState();
}

class _ComprasDashboardPageState extends State<ComprasDashboardPage> {
  bool _menuOpen = false;
  bool _loading = true;
  bool _canReturnToDirection = false;
  bool _canAccessFinanzasArea = false;
  List<ComprasTicketRecord> _tickets = const <ComprasTicketRecord>[];
  ComprasCatalogSnapshot? _snapshot;
  List<ComprasPriceHistoryRecord> _priceHistory =
      const <ComprasPriceHistoryRecord>[];
  List<ComprasProviderDirectoryRecord> _directory =
      const <ComprasProviderDirectoryRecord>[];
  String? _amountProviderFilterId;
  String? _weightMaterialFilterId;
  String? _avgPriceMaterialFilterId;
  _ComprasDashboardSummary _summary = const _ComprasDashboardSummary.empty();

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
      _canAccessFinanzasArea = AuthAccess.canAccessFinanzasArea(profile);
    });
  }

  Future<void> _loadDashboard({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    final results = await Future.wait<dynamic>([
      ComprasTicketsStore.loadTickets(),
      ComprasDataStore.loadCatalogSnapshot(),
      ComprasDataStore.loadPriceHistory(),
      ComprasProviderDirectoryStore.loadDirectory(),
    ]);
    if (!mounted) return;
    final tickets = results[0] as List<ComprasTicketRecord>;
    final snapshot = results[1] as ComprasCatalogSnapshot;
    final priceHistory = results[2] as List<ComprasPriceHistoryRecord>;
    final directory = results[3] as List<ComprasProviderDirectoryRecord>;
    setState(() {
      _tickets = tickets;
      _snapshot = snapshot;
      _priceHistory = priceHistory;
      _directory = directory;
      _summary = _computeSummary();
      _loading = false;
    });
  }

  _ComprasDashboardSummary _computeSummary() {
    final snapshot = _snapshot;
    if (snapshot == null) return const _ComprasDashboardSummary.empty();
    return _buildComprasDashboardSummary(
      tickets: _tickets,
      snapshot: snapshot,
      priceHistory: _priceHistory,
      directory: _directory,
      selectedAmountProviderId: _amountProviderFilterId,
      selectedWeightMaterialId: _weightMaterialFilterId,
      selectedAvgPriceMaterialId: _avgPriceMaterialFilterId,
    );
  }

  void _setAmountProviderFilter(String? providerId) {
    setState(() {
      _amountProviderFilterId = providerId;
      _summary = _computeSummary();
    });
  }

  void _setWeightMaterialFilter(String? materialId) {
    setState(() {
      _weightMaterialFilterId = materialId;
      _summary = _computeSummary();
    });
  }

  void _setAvgPriceMaterialFilter(String? materialId) {
    setState(() {
      _avgPriceMaterialFilterId = materialId;
      _summary = _computeSummary();
    });
  }

  Future<void> _logout() async {
    await signOutAndRouteToLogin(context);
  }

  Future<void> _openCatalog() async {
    await Navigator.of(
      context,
    ).push(appPageRoute(page: const ComprasCatalogPage(instantOpen: true)));
  }

  Future<void> _openTickets() async {
    await Navigator.of(
      context,
    ).push(appPageRoute(page: const ComprasTicketsPage(instantOpen: true)));
  }

  Future<void> _openPriceAdjustments() async {
    await Navigator.of(context).push(
      appPageRoute(page: const ComprasPriceAdjustmentsPage(instantOpen: true)),
    );
  }

  Future<void> _openDirectory() async {
    await Navigator.of(context).push(
      appPageRoute(page: const ComprasProviderDirectoryPage(instantOpen: true)),
    );
  }

  Future<void> _openFinanzas() async {
    await Navigator.of(
      context,
    ).push(appPageRoute(page: const FinanzasDashboardPage(instantOpen: true)));
  }

  Future<void> _openDirectionDashboard() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AreaThemeScope(
      tokens: comprasAreaTokens,
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
          background: const ComprasAreaBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 8,
          padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
          leadingBuilder: (_, _) => ComprasAreaHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegación',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, _) => const _ComprasDashboardHeaderBrand(),
          trailingBuilder: (_, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ComprasAreaHeaderButton(
                label: 'Correo',
                icon: Icons.mail_outline_rounded,
                compact: true,
                onTap: () => openComprasMailHostinger(context),
              ),
              const SizedBox(width: 10),
              ComprasAreaHeaderButton(
                label: 'Cerrar sesión',
                icon: Icons.logout_rounded,
                onTap: _logout,
              ),
            ],
          ),
          child: Stack(
            children: [
              _ComprasDashboardBody(
                loading: _loading,
                summary: _summary,
                onAmountProviderFilterChanged: _setAmountProviderFilter,
                onWeightMaterialFilterChanged: _setWeightMaterialFilter,
                onAvgPriceMaterialFilterChanged: _setAvgPriceMaterialFilter,
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
                        color: Colors.black.withValues(alpha: 0.12),
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
                  child: ComprasAreaSidePanel(
                    label: 'Compras Mayoreo',
                    canReturnToDirection: _canReturnToDirection,
                    areaItems: [
                      ComprasAreaNavEntry(
                        icon: Icons.confirmation_number_outlined,
                        title: 'Tickets Compras',
                        subtitle: 'Captura y seguimiento operativo',
                        onTap: _openTickets,
                      ),
                      ComprasAreaNavEntry(
                        icon: Icons.tune_rounded,
                        title: 'Ajuste de precios',
                        subtitle: 'Vigentes e historial operativo',
                        onTap: _openPriceAdjustments,
                      ),
                      ComprasAreaNavEntry(
                        icon: Icons.price_check_rounded,
                        title: 'Catálogo Compras',
                        subtitle: 'Proveedores, materiales y precios',
                        onTap: _openCatalog,
                      ),
                      ComprasAreaNavEntry(
                        icon: Icons.badge_rounded,
                        title: 'Directorio Proveedores',
                        subtitle: 'Crédito, contacto y operación',
                        onTap: _openDirectory,
                      ),
                    ],
                    accessItems: [
                      const ComprasAreaNavEntry(
                        icon: Icons.shopping_cart_checkout_rounded,
                        title: 'Dashboard Compras',
                        subtitle: 'Lectura ejecutiva mensual',
                        accented: true,
                      ),
                      if (_canAccessFinanzasArea)
                        ComprasAreaNavEntry(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'Dashboard Finanzas',
                          subtitle: 'Pagos, liquidez y compromisos',
                          onTap: _openFinanzas,
                        ),
                      if (_canReturnToDirection)
                        ComprasAreaNavEntry(
                          icon: Icons.assessment_outlined,
                          title: 'Dashboard Dirección',
                          subtitle: 'Vista ejecutiva multiarea',
                          onTap: _openDirectionDashboard,
                        ),
                    ],
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

class _ComprasDashboardHeaderBrand extends StatelessWidget {
  const _ComprasDashboardHeaderBrand();

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
            color: Colors.white.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.44)),
            boxShadow: [
              BoxShadow(
                color: tokens.primaryStrong.withValues(alpha: 0.16),
                blurRadius: 24,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(child: DicsaLogoD(size: 40, progress: 1)),
        ),
        const SizedBox(width: 10),
        Container(
          width: 1.5,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: tokens.primaryStrong.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'Dashboard Compras',
          maxLines: 1,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.25,
            height: 1.0,
            color: Color(0xFFE6DBD8),
          ),
        ),
      ],
    );
  }
}

class _ComprasDashboardBody extends StatelessWidget {
  final bool loading;
  final _ComprasDashboardSummary summary;
  final ValueChanged<String?> onAmountProviderFilterChanged;
  final ValueChanged<String?> onWeightMaterialFilterChanged;
  final ValueChanged<String?> onAvgPriceMaterialFilterChanged;

  const _ComprasDashboardBody({
    required this.loading,
    required this.summary,
    required this.onAmountProviderFilterChanged,
    required this.onWeightMaterialFilterChanged,
    required this.onAvgPriceMaterialFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 56, right: 2, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MetricCardsWrap(
                summary: summary,
                loading: loading,
                onAmountProviderFilterChanged: onAmountProviderFilterChanged,
                onWeightMaterialFilterChanged: onWeightMaterialFilterChanged,
                onAvgPriceMaterialFilterChanged:
                    onAvgPriceMaterialFilterChanged,
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1120;
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _BreakdownBlock(
                            title: 'Compras Por Material',
                            subtitle:
                                'Volumen, importe, precio promedio y participación mensual.',
                            rows: summary.materialRows,
                            emptyLabel:
                                'Todavía no hay materiales con compra en el mes.',
                            accent: const Color(0xFF64D86B),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _BreakdownBlock(
                            title: 'Compras Por Proveedor',
                            subtitle:
                                'Concentración mensual para detectar dependencia y costo.',
                            rows: summary.providerRows,
                            emptyLabel:
                                'Todavía no hay proveedores con compra en el mes.',
                            accent: const Color(0xFF5F89FF),
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      _BreakdownBlock(
                        title: 'Compras Por Material',
                        subtitle:
                            'Volumen, importe, precio promedio y participación mensual.',
                        rows: summary.materialRows,
                        emptyLabel:
                            'Todavía no hay materiales con compra en el mes.',
                        accent: const Color(0xFF64D86B),
                      ),
                      const SizedBox(height: 16),
                      _BreakdownBlock(
                        title: 'Compras Por Proveedor',
                        subtitle:
                            'Concentración mensual para detectar dependencia y costo.',
                        rows: summary.providerRows,
                        emptyLabel:
                            'Todavía no hay proveedores con compra en el mes.',
                        accent: const Color(0xFF5F89FF),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1120;
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _PriceReadBlock(
                            rows: summary.priceRows,
                            loading: loading,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _AlertsFinanceBlock(
                            alerts: summary.alerts,
                            financeRows: summary.financeRows,
                            loading: loading,
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      _PriceReadBlock(
                        rows: summary.priceRows,
                        loading: loading,
                      ),
                      const SizedBox(height: 16),
                      _AlertsFinanceBlock(
                        alerts: summary.alerts,
                        financeRows: summary.financeRows,
                        loading: loading,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCardsWrap extends StatelessWidget {
  final _ComprasDashboardSummary summary;
  final bool loading;
  final ValueChanged<String?> onAmountProviderFilterChanged;
  final ValueChanged<String?> onWeightMaterialFilterChanged;
  final ValueChanged<String?> onAvgPriceMaterialFilterChanged;

  const _MetricCardsWrap({
    required this.summary,
    required this.loading,
    required this.onAmountProviderFilterChanged,
    required this.onWeightMaterialFilterChanged,
    required this.onAvgPriceMaterialFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final current = summary.currentMonth;
    final previous = summary.previousMonth;
    const spacing = 16.0;
    const preferredCardWidth = 220.0;
    const cardHeight = 184.0;
    final cards = [
      _MetricCardData(
        title: 'Importe mensual',
        value: loading
            ? 'Cargando...'
            : formatMoney(summary.amountMetric.current),
        detail: summary.amountMetric.detail,
        icon: Icons.attach_money_rounded,
        accent: const Color(0xFF64D86B),
        filterValue: summary.selectedAmountProviderLabel,
        filterOptions: summary.providerFilterOptions,
        onFilterSelected: onAmountProviderFilterChanged,
        filterPlaceholder: 'Todos los proveedores',
      ),
      _MetricCardData(
        title: 'Kg comprados',
        value: loading ? 'Cargando...' : _kg(summary.weightMetric.current),
        detail: summary.weightMetric.detail,
        icon: Icons.scale_rounded,
        accent: const Color(0xFF72E482),
        filterValue: summary.selectedWeightMaterialLabel,
        filterOptions: summary.materialFilterOptions,
        onFilterSelected: onWeightMaterialFilterChanged,
        filterPlaceholder: 'Todos los materiales',
      ),
      _MetricCardData(
        title: 'Precio promedio',
        value: loading
            ? 'Cargando...'
            : formatMoney(summary.avgPriceMetric.current),
        detail: summary.avgPriceMetric.detail,
        icon: Icons.sell_outlined,
        accent: const Color(0xFF5F89FF),
        filterValue: summary.selectedAvgPriceMaterialLabel,
        filterOptions: summary.materialFilterOptions,
        onFilterSelected: onAvgPriceMaterialFilterChanged,
        filterPlaceholder: 'Todos los materiales',
      ),
      _MetricCardData(
        title: 'Tickets del mes',
        value: loading ? 'Cargando...' : '${current.ticketCount}',
        detail: '${previous.ticketCount} tickets mes anterior',
        icon: Icons.confirmation_number_outlined,
        accent: const Color(0xFF8A63FF),
      ),
      _MetricCardData(
        title: 'Proveedores activos',
        value: loading ? 'Cargando...' : '${current.providerCount}',
        detail: '${current.providerCount} con compra este mes',
        icon: Icons.groups_2_outlined,
        accent: const Color(0xFF66D1FF),
      ),
      _MetricCardData(
        title: 'Materiales comprados',
        value: loading ? 'Cargando...' : '${current.materialCount}',
        detail: '${current.materialCount} materiales con movimiento',
        icon: Icons.layers_outlined,
        accent: const Color(0xFF7D74FF),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final totalSpacing = spacing * (cards.length - 1);
        final fittedWidth = (availableWidth - totalSpacing) / cards.length;
        final cardWidth = fittedWidth >= 184 ? fittedWidth : preferredCardWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < cards.length; index += 1) ...[
                SizedBox(
                  width: cardWidth,
                  height: cardHeight,
                  child: _MetricCard(data: cards[index]),
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

class _MetricCardData {
  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color accent;
  final String? filterValue;
  final List<_DashboardFilterOption> filterOptions;
  final ValueChanged<String?>? onFilterSelected;
  final String? filterPlaceholder;

  const _MetricCardData({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.accent,
    this.filterValue,
    this.filterOptions = const <_DashboardFilterOption>[],
    this.onFilterSelected,
    this.filterPlaceholder,
  });
}

class _MetricCard extends StatelessWidget {
  final _MetricCardData data;

  const _MetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final hasFilter =
        data.onFilterSelected != null && data.filterOptions.isNotEmpty;
    return ContractGlassCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: data.accent.withValues(alpha: 0.10),
              border: Border.all(color: data.accent.withValues(alpha: 0.28)),
              boxShadow: [
                BoxShadow(
                  color: data.accent.withValues(alpha: 0.12),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(data.icon, color: data.accent, size: 34),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: tokens.onGlass.withValues(alpha: 0.94),
                  ),
                ),
                if (hasFilter) ...[
                  const SizedBox(height: 8),
                  _MetricFilterButton(
                    label:
                        data.filterValue ?? data.filterPlaceholder ?? 'Todos',
                    options: data.filterOptions,
                    onSelected: data.onFilterSelected!,
                  ),
                  const SizedBox(height: 8),
                ] else
                  const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    data.value,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: tokens.onGlass,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tokens.badgeText,
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

class _MetricFilterButton extends StatelessWidget {
  final String label;
  final List<_DashboardFilterOption> options;
  final ValueChanged<String?> onSelected;

  const _MetricFilterButton({
    required this.label,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return PopupMenuButton<String?>(
      tooltip: 'Filtrar tarjeta',
      offset: const Offset(0, 36),
      onSelected: onSelected,
      color: tokens.glassSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        PopupMenuItem<String?>(
          value: null,
          child: Text(
            'Todos',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: tokens.onGlass,
            ),
          ),
        ),
        for (final option in options)
          PopupMenuItem<String?>(
            value: option.id,
            child: Text(
              option.label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: tokens.onGlass,
              ),
            ),
          ),
      ],
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: tokens.fieldSurface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tokens.border.withValues(alpha: 0.70)),
        ),
        child: Row(
          children: [
            Icon(Icons.filter_alt_outlined, size: 14, color: tokens.badgeText),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: tokens.badgeText,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: tokens.badgeText,
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_ComprasBreakdownRow> rows;
  final String emptyLabel;
  final Color accent;

  const _BreakdownBlock({
    required this.title,
    required this.subtitle,
    required this.rows,
    required this.emptyLabel,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final lead = rows.isEmpty ? null : rows.first;
    return ContractGlassCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(title: title, subtitle: subtitle),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            Text(
              emptyLabel,
              style: TextStyle(
                color: tokens.badgeText,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Column(
              children: [
                _BreakdownHeroRow(row: lead!, accent: accent),
                if (rows.length > 1) ...[
                  const SizedBox(height: 12),
                  for (final row in rows.skip(1).take(4))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _BreakdownMiniRow(row: row, accent: accent),
                    ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _BreakdownHeroRow extends StatelessWidget {
  final _ComprasBreakdownRow row;
  final Color accent;

  const _BreakdownHeroRow({required this.row, required this.accent});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: tokens.fieldSurface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tokens.border.withValues(alpha: 0.72)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final ring = _BreakdownRing(share: row.share, accent: accent);
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: tokens.onGlass,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    row.shareLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: tokens.onGlass,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 11,
                  value: (row.share / 100).clamp(0.0, 1.0),
                  backgroundColor: tokens.badgeBackground.withValues(
                    alpha: 0.56,
                  ),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 30,
                runSpacing: 12,
                children: [
                  _BlockStat(label: 'Importe', value: formatMoney(row.amount)),
                  _BlockStat(label: 'Kg', value: _kg(row.weight)),
                  _BlockStat(
                    label: 'Promedio',
                    value: formatMoney(row.avgPrice),
                  ),
                ],
              ),
            ],
          );
          if (compact) {
            return Column(
              children: [ring, const SizedBox(height: 18), details],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ring,
              const SizedBox(width: 24),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}

class _BreakdownMiniRow extends StatelessWidget {
  final _ComprasBreakdownRow row;
  final Color accent;

  const _BreakdownMiniRow({required this.row, required this.accent});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.fieldSurface.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border.withValues(alpha: 0.58)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              row.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: tokens.onGlass,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: (row.share / 100).clamp(0.0, 1.0),
                backgroundColor: tokens.badgeBackground.withValues(alpha: 0.56),
                valueColor: AlwaysStoppedAnimation<Color>(
                  accent.withValues(alpha: 0.90),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            row.shareLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: tokens.badgeText,
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRing extends StatelessWidget {
  final double share;
  final Color accent;

  const _BreakdownRing({required this.share, required this.accent});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return SizedBox(
      width: 168,
      height: 168,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 168,
            height: 168,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 18,
              color: tokens.badgeBackground.withValues(alpha: 0.56),
            ),
          ),
          SizedBox(
            width: 168,
            height: 168,
            child: CircularProgressIndicator(
              value: (share / 100).clamp(0.0, 1.0),
              strokeWidth: 18,
              color: accent,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${formatDecimal(share, decimals: 1)}%',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'del total',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: tokens.badgeText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BlockStat extends StatelessWidget {
  final String label;
  final String value;

  const _BlockStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: tokens.badgeText,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: tokens.onGlass,
          ),
        ),
      ],
    );
  }
}

class _PriceReadBlock extends StatelessWidget {
  final List<_ComprasPriceReadRow> rows;
  final bool loading;

  const _PriceReadBlock({required this.rows, required this.loading});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return ContractGlassCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            title: 'Precio Real Vs Vigente',
            subtitle:
                'Comparativo mensual para ubicar desvíos de costo y materiales con sobreprecio.',
          ),
          const SizedBox(height: 14),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (rows.isEmpty)
            Text(
              'Todavía no hay suficientes compras del mes para comparar precio real contra vigente.',
              style: TextStyle(
                color: tokens.badgeText,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Column(
              children: [
                _PriceReadHeader(tokens: tokens),
                const SizedBox(height: 10),
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PriceReadRowTile(row: row),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PriceReadHeader extends StatelessWidget {
  final dynamic tokens;

  const _PriceReadHeader({required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(flex: 3, child: _HeaderText('Material')),
        const Expanded(child: _HeaderText('Real')),
        const Expanded(child: _HeaderText('Vigente')),
        const Expanded(child: _HeaderText('Desvío')),
        const Expanded(child: _HeaderText('Sobreprecios')),
      ],
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String label;

  const _HeaderText(this.label);

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Text(
      label,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w900,
        color: tokens.badgeText,
      ),
    );
  }
}

class _PriceReadRowTile extends StatelessWidget {
  final _ComprasPriceReadRow row;

  const _PriceReadRowTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final positive = row.deltaPercent >= 0;
    final tone = positive ? const Color(0xFFF0B44C) : const Color(0xFF7FD6B5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.fieldSurface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              row.material,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: tokens.onGlass,
              ),
            ),
          ),
          Expanded(child: Text(formatMoney(row.avgPaid), style: _valueStyle())),
          Expanded(
            child: Text(formatMoney(row.avgVigente), style: _valueStyle()),
          ),
          Expanded(
            child: Text(
              '${positive ? '+' : ''}${formatDecimal(row.deltaPercent, decimals: 1)}%',
              style: _valueStyle(color: tone),
            ),
          ),
          Expanded(child: Text('${row.premiumCount}', style: _valueStyle())),
        ],
      ),
    );
  }

  TextStyle _valueStyle({Color? color}) => TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w800,
    color: color ?? comprasAreaTokens.onGlass,
  );
}

class _AlertsFinanceBlock extends StatelessWidget {
  final List<String> alerts;
  final List<_ComprasFinanceRow> financeRows;
  final bool loading;

  const _AlertsFinanceBlock({
    required this.alerts,
    required this.financeRows,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Column(
      children: [
        ContractGlassCard(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeading(
                title: 'Alertas Ejecutivas',
                subtitle:
                    'Señales rápidas para decidir sobre costo, concentración y riesgo operativo.',
              ),
              const SizedBox(height: 14),
              if (loading)
                const Center(child: CircularProgressIndicator())
              else if (alerts.isEmpty)
                Text(
                  'Sin alertas relevantes en la lectura mensual actual.',
                  style: TextStyle(
                    color: tokens.badgeText,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                Column(
                  children: [
                    for (var index = 0; index < alerts.length; index += 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _AlertTile(
                          text: alerts[index],
                          accent: _alertAccentForIndex(index),
                          icon: _alertIconForIndex(index),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ContractGlassCard(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeading(
                title: 'Cruce Con Finanzas',
                subtitle:
                    'Exposición abierta por proveedor y presión de pago asociada a la compra.',
              ),
              const SizedBox(height: 14),
              if (loading)
                const Center(child: CircularProgressIndicator())
              else if (financeRows.isEmpty)
                Text(
                  'No hay exposición abierta relevante para mostrar.',
                  style: TextStyle(
                    color: tokens.badgeText,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                Column(
                  children: [
                    for (final row in financeRows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _FinanceRowTile(row: row),
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

class _AlertTile extends StatelessWidget {
  final String text;
  final Color accent;
  final IconData icon;

  const _AlertTile({
    required this.text,
    required this.accent,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.fieldSurface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border.withValues(alpha: 0.72)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.10),
              border: Border.all(color: accent.withValues(alpha: 0.26)),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: tokens.onGlass,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _alertAccentForIndex(int index) {
  switch (index % 4) {
    case 0:
      return const Color(0xFF64D86B);
    case 1:
      return const Color(0xFF5F89FF);
    case 2:
      return const Color(0xFFF0B44C);
    default:
      return const Color(0xFF8A63FF);
  }
}

IconData _alertIconForIndex(int index) {
  switch (index % 4) {
    case 0:
      return Icons.check_circle_outline_rounded;
    case 1:
      return Icons.arrow_circle_up_outlined;
    case 2:
      return Icons.warning_amber_rounded;
    default:
      return Icons.insights_rounded;
  }
}

class _FinanceInlineStat extends StatelessWidget {
  final String label;
  final String value;

  const _FinanceInlineStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Text(
      '$label: $value',
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        color: tokens.onGlass,
        height: 1.35,
      ),
    );
  }
}

class _FinanceRowTile extends StatelessWidget {
  final _ComprasFinanceRow row;

  const _FinanceRowTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final tone = _dashboardPaymentStageTone(row.paymentStage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.fieldSurface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.provider,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: tokens.onGlass,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _DashboardPaymentBadge(
                label: _dashboardPaymentStageLabel(row.paymentStage),
                active: row.paymentStage != 'AL_CORRIENTE',
                tone: tone,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _FinanceInlineStat(
                label: 'Pendiente',
                value: formatMoney(row.openAmount),
              ),
              _FinanceInlineStat(
                label: 'Mes',
                value: formatMoney(row.monthAmount),
              ),
              _FinanceInlineStat(
                label: 'Crédito',
                value: row.creditDays > 0
                    ? '${row.creditDays} días'
                    : 'Sin crédito',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _dashboardPaymentStageLabel(String stage) {
  switch (stage) {
    case 'ATRASADO':
      return 'Atrasado';
    case 'CONVENIO':
      return 'Convenio';
    case 'PAGO_SEMANAL':
      return 'Pago semanal';
    default:
      return 'Al corriente';
  }
}

Color _dashboardPaymentStageTone(String stage) {
  switch (stage) {
    case 'ATRASADO':
      return const Color(0xFFB42318);
    case 'CONVENIO':
      return const Color(0xFFB7C0C8);
    case 'PAGO_SEMANAL':
      return const Color(0xFF8B5E00);
    default:
      return const Color(0xFF0F766E);
  }
}

class _DashboardPaymentBadge extends StatelessWidget {
  final String label;
  final bool active;
  final Color tone;

  const _DashboardPaymentBadge({
    required this.label,
    required this.active,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: active
            ? tone.withValues(alpha: 0.10)
            : tokens.badgeBackground.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? tone.withValues(alpha: 0.24)
              : tokens.border.withValues(alpha: 0.70),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: active ? tone : tokens.badgeText,
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeading({required this.title, required this.subtitle});

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
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: tokens.badgeText,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _ComprasDashboardSummary {
  final _ComprasMonthAggregate currentMonth;
  final _ComprasMonthAggregate previousMonth;
  final _DashboardMetricValue amountMetric;
  final _DashboardMetricValue weightMetric;
  final _DashboardMetricValue avgPriceMetric;
  final List<_ComprasBreakdownRow> materialRows;
  final List<_ComprasBreakdownRow> providerRows;
  final List<_ComprasPriceReadRow> priceRows;
  final List<String> alerts;
  final List<_ComprasFinanceRow> financeRows;
  final List<_DashboardFilterOption> providerFilterOptions;
  final List<_DashboardFilterOption> materialFilterOptions;
  final String? selectedAmountProviderLabel;
  final String? selectedWeightMaterialLabel;
  final String? selectedAvgPriceMaterialLabel;

  const _ComprasDashboardSummary({
    required this.currentMonth,
    required this.previousMonth,
    required this.amountMetric,
    required this.weightMetric,
    required this.avgPriceMetric,
    required this.materialRows,
    required this.providerRows,
    required this.priceRows,
    required this.alerts,
    required this.financeRows,
    required this.providerFilterOptions,
    required this.materialFilterOptions,
    required this.selectedAmountProviderLabel,
    required this.selectedWeightMaterialLabel,
    required this.selectedAvgPriceMaterialLabel,
  });

  const _ComprasDashboardSummary.empty()
    : currentMonth = const _ComprasMonthAggregate.empty(),
      previousMonth = const _ComprasMonthAggregate.empty(),
      amountMetric = const _DashboardMetricValue.empty(),
      weightMetric = const _DashboardMetricValue.empty(),
      avgPriceMetric = const _DashboardMetricValue.empty(),
      materialRows = const <_ComprasBreakdownRow>[],
      providerRows = const <_ComprasBreakdownRow>[],
      priceRows = const <_ComprasPriceReadRow>[],
      alerts = const <String>[],
      financeRows = const <_ComprasFinanceRow>[],
      providerFilterOptions = const <_DashboardFilterOption>[],
      materialFilterOptions = const <_DashboardFilterOption>[],
      selectedAmountProviderLabel = null,
      selectedWeightMaterialLabel = null,
      selectedAvgPriceMaterialLabel = null;
}

class _DashboardMetricValue {
  final double current;
  final double previous;
  final String detail;

  const _DashboardMetricValue({
    required this.current,
    required this.previous,
    required this.detail,
  });

  const _DashboardMetricValue.empty()
    : current = 0,
      previous = 0,
      detail = 'Sin movimiento relevante';
}

class _DashboardFilterOption {
  final String id;
  final String label;

  const _DashboardFilterOption({required this.id, required this.label});
}

class _ComprasMonthAggregate {
  final double totalAmount;
  final double totalWeight;
  final double avgPrice;
  final int ticketCount;
  final int providerCount;
  final int materialCount;

  const _ComprasMonthAggregate({
    required this.totalAmount,
    required this.totalWeight,
    required this.avgPrice,
    required this.ticketCount,
    required this.providerCount,
    required this.materialCount,
  });

  const _ComprasMonthAggregate.empty()
    : totalAmount = 0,
      totalWeight = 0,
      avgPrice = 0,
      ticketCount = 0,
      providerCount = 0,
      materialCount = 0;
}

class _ComprasBreakdownRow {
  final String label;
  final double amount;
  final double weight;
  final double avgPrice;
  final double share;

  const _ComprasBreakdownRow({
    required this.label,
    required this.amount,
    required this.weight,
    required this.avgPrice,
    required this.share,
  });

  String get shareLabel => '${formatDecimal(share, decimals: 1)}% del total';
}

class _ComprasPriceReadRow {
  final String material;
  final double avgPaid;
  final double avgVigente;
  final double deltaPercent;
  final int premiumCount;

  const _ComprasPriceReadRow({
    required this.material,
    required this.avgPaid,
    required this.avgVigente,
    required this.deltaPercent,
    required this.premiumCount,
  });
}

class _ComprasFinanceRow {
  final String provider;
  final double openAmount;
  final double monthAmount;
  final String paymentStage;
  final int creditDays;

  const _ComprasFinanceRow({
    required this.provider,
    required this.openAmount,
    required this.monthAmount,
    required this.paymentStage,
    required this.creditDays,
  });
}

_ComprasDashboardSummary _buildComprasDashboardSummary({
  required List<ComprasTicketRecord> tickets,
  required ComprasCatalogSnapshot snapshot,
  required List<ComprasPriceHistoryRecord> priceHistory,
  required List<ComprasProviderDirectoryRecord> directory,
  required String? selectedAmountProviderId,
  required String? selectedWeightMaterialId,
  required String? selectedAvgPriceMaterialId,
}) {
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month);
  final nextMonthStart = DateTime(now.year, now.month + 1);
  final prevMonthStart = DateTime(now.year, now.month - 1);
  final currentMonthTickets = tickets
      .where(
        (row) =>
            !row.date.isBefore(monthStart) && row.date.isBefore(nextMonthStart),
      )
      .toList(growable: false);
  final previousMonthTickets = tickets
      .where(
        (row) =>
            !row.date.isBefore(prevMonthStart) && row.date.isBefore(monthStart),
      )
      .toList(growable: false);
  final currentAgg = _aggregateMonth(currentMonthTickets);
  final previousAgg = _aggregateMonth(previousMonthTickets);
  final providerFilterOptions = _buildFilterOptions(
    rows: currentMonthTickets,
    idFor: (row) => row.providerId,
    labelFor: (row) => row.providerNameSnapshot,
  );
  final materialFilterOptions = _buildFilterOptions(
    rows: currentMonthTickets,
    idFor: (row) => row.materialId,
    labelFor: (row) => row.materialNameSnapshot,
  );
  final amountCurrentRows = _filterTicketsByProvider(
    currentMonthTickets,
    selectedAmountProviderId,
  );
  final amountPreviousRows = _filterTicketsByProvider(
    previousMonthTickets,
    selectedAmountProviderId,
  );
  final weightCurrentRows = _filterTicketsByMaterial(
    currentMonthTickets,
    selectedWeightMaterialId,
  );
  final weightPreviousRows = _filterTicketsByMaterial(
    previousMonthTickets,
    selectedWeightMaterialId,
  );
  final avgPriceCurrentRows = _filterTicketsByMaterial(
    currentMonthTickets,
    selectedAvgPriceMaterialId,
  );
  final avgPricePreviousRows = _filterTicketsByMaterial(
    previousMonthTickets,
    selectedAvgPriceMaterialId,
  );
  final amountCurrent = amountCurrentRows.fold<double>(
    0,
    (sum, row) => sum + row.amount,
  );
  final amountPrevious = amountPreviousRows.fold<double>(
    0,
    (sum, row) => sum + row.amount,
  );
  final weightCurrent = weightCurrentRows.fold<double>(
    0,
    (sum, row) => sum + row.payableWeight,
  );
  final weightPrevious = weightPreviousRows.fold<double>(
    0,
    (sum, row) => sum + row.payableWeight,
  );
  final avgPriceCurrent = _weightedAveragePrice(avgPriceCurrentRows);
  final avgPricePrevious = _weightedAveragePrice(avgPricePreviousRows);

  final materialRows = _buildBreakdownRows(
    rows: currentMonthTickets,
    labelFor: (row) => row.materialNameSnapshot,
    totalAmount: currentAgg.totalAmount,
  );
  final providerRows = _buildBreakdownRows(
    rows: currentMonthTickets,
    labelFor: (row) => row.providerNameSnapshot,
    totalAmount: currentAgg.totalAmount,
  );

  final activePriceRows = snapshot.prices.where((row) => row.active);
  final vigenteByMaterialId = <String, List<double>>{};
  for (final row in activePriceRows) {
    vigenteByMaterialId
        .putIfAbsent(row.materialId, () => <double>[])
        .add(row.amount);
  }
  final currentTicketsByMaterial = <String, List<ComprasTicketRecord>>{};
  for (final row in currentMonthTickets) {
    currentTicketsByMaterial
        .putIfAbsent(row.materialId, () => <ComprasTicketRecord>[])
        .add(row);
  }
  final priceRows = <_ComprasPriceReadRow>[];
  currentTicketsByMaterial.forEach((materialId, rows) {
    final materialName = rows.first.materialNameSnapshot;
    final avgPaid = _weightedAveragePrice(rows);
    final vigente = vigenteByMaterialId[materialId];
    if (vigente == null || vigente.isEmpty) return;
    final avgVigente = vigente.reduce((a, b) => a + b) / vigente.length;
    final deltaPercent = avgVigente.abs() < 0.0001
        ? 0.0
        : ((avgPaid - avgVigente) / avgVigente) * 100;
    priceRows.add(
      _ComprasPriceReadRow(
        material: materialName,
        avgPaid: avgPaid,
        avgVigente: avgVigente,
        deltaPercent: deltaPercent,
        premiumCount: rows.where((row) => row.premium > 0.009).length,
      ),
    );
  });
  priceRows.sort(
    (a, b) => b.deltaPercent.abs().compareTo(a.deltaPercent.abs()),
  );

  final directoryByProviderId = <String, ComprasProviderDirectoryRecord>{
    for (final row in directory) row.providerId: row,
  };
  final openAmountByProviderId = <String, double>{};
  for (final row in tickets.where((row) => row.pagoStatus != 'PAGADO')) {
    openAmountByProviderId.update(
      row.providerId,
      (value) => value + row.amount,
      ifAbsent: () => row.amount,
    );
  }
  final monthAmountByProviderId = <String, double>{};
  for (final row in currentMonthTickets) {
    monthAmountByProviderId.update(
      row.providerId,
      (value) => value + row.amount,
      ifAbsent: () => row.amount,
    );
  }
  final financeRows =
      monthAmountByProviderId.entries
          .map((entry) {
            final directoryRow = directoryByProviderId[entry.key];
            final providerName =
                directoryRow?.providerName ??
                currentMonthTickets
                    .firstWhere((row) => row.providerId == entry.key)
                    .providerNameSnapshot;
            return _ComprasFinanceRow(
              provider: providerName,
              openAmount: openAmountByProviderId[entry.key] ?? 0,
              monthAmount: entry.value,
              paymentStage: directoryRow?.paymentStage ?? 'AL_CORRIENTE',
              creditDays: directoryRow?.creditDays ?? 0,
            );
          })
          .where(
            (row) =>
                row.openAmount > 0.009 || row.paymentStage != 'AL_CORRIENTE',
          )
          .toList(growable: false)
        ..sort((a, b) => b.openAmount.compareTo(a.openAmount));

  final alerts = <String>[];
  if (materialRows.isNotEmpty) {
    final top = materialRows.first;
    alerts.add(
      '${top.label} concentra ${top.shareLabel.toLowerCase()} con ${_kg(top.weight)} y ${formatMoney(top.amount)} este mes.',
    );
  }
  if (providerRows.isNotEmpty) {
    final top = providerRows.first;
    alerts.add(
      '${top.label} es el proveedor con mayor compra mensual: ${formatMoney(top.amount)} a ${formatMoney(top.avgPrice)} promedio.',
    );
  }
  for (final row in priceRows.take(2)) {
    if (row.deltaPercent > 3) {
      alerts.add(
        '${row.material} se está pagando ${formatDecimal(row.deltaPercent, decimals: 1)}% arriba del vigente promedio.',
      );
    }
  }
  for (final row in financeRows.take(2)) {
    if (row.paymentStage != 'AL_CORRIENTE') {
      alerts.add(
        '${row.provider} combina compra mensual por ${formatMoney(row.monthAmount)} con situación ${_dashboardPaymentStageLabel(row.paymentStage).toLowerCase()}.',
      );
    }
  }
  if (alerts.isEmpty && currentAgg.ticketCount > 0) {
    alerts.add(
      'La compra mensual está operando sin alertas fuertes de concentración o desvío contra vigente.',
    );
  }

  final currentMonthHistory = priceHistory
      .where(
        (row) =>
            !row.createdAt.isBefore(monthStart) &&
            row.createdAt.isBefore(nextMonthStart),
      )
      .toList(growable: false);
  final premiumHeavyMaterials = <String, int>{};
  for (final row in currentMonthTickets.where((row) => row.premium > 0.009)) {
    premiumHeavyMaterials.update(
      row.materialNameSnapshot,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
  }
  if (currentMonthHistory.isNotEmpty) {
    final biggest = currentMonthHistory.reduce(
      (a, b) =>
          (a.newPrice - a.previousPrice).abs() >=
              (b.newPrice - b.previousPrice).abs()
          ? a
          : b,
    );
    alerts.add(
      'El mayor cambio de precio del mes fue ${biggest.materialName}: ${formatMoney(biggest.previousPrice)} a ${formatMoney(biggest.newPrice)}.',
    );
  }
  if (premiumHeavyMaterials.isNotEmpty) {
    final topPremium = premiumHeavyMaterials.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    alerts.add(
      '${topPremium.key} registró ${topPremium.value} ticket(s) con sobreprecio este mes.',
    );
  }

  return _ComprasDashboardSummary(
    currentMonth: currentAgg,
    previousMonth: previousAgg,
    amountMetric: _DashboardMetricValue(
      current: amountCurrent,
      previous: amountPrevious,
      detail: _changeLine(
        current: amountCurrent,
        previous: amountPrevious,
        suffix: selectedAmountProviderId == null
            ? 'vs mes anterior'
            : 'vs mes anterior del proveedor',
      ),
    ),
    weightMetric: _DashboardMetricValue(
      current: weightCurrent,
      previous: weightPrevious,
      detail: _changeLine(
        current: weightCurrent,
        previous: weightPrevious,
        suffix: selectedWeightMaterialId == null
            ? 'vs mes anterior'
            : 'vs mes anterior del material',
      ),
    ),
    avgPriceMetric: _DashboardMetricValue(
      current: avgPriceCurrent,
      previous: avgPricePrevious,
      detail: _changeLine(
        current: avgPriceCurrent,
        previous: avgPricePrevious,
        suffix: selectedAvgPriceMaterialId == null
            ? 'ponderado por kg'
            : 'promedio mensual filtrado',
      ),
    ),
    materialRows: materialRows.take(6).toList(growable: false),
    providerRows: providerRows.take(6).toList(growable: false),
    priceRows: priceRows.take(7).toList(growable: false),
    alerts: alerts.take(6).toList(growable: false),
    financeRows: financeRows.take(5).toList(growable: false),
    providerFilterOptions: providerFilterOptions,
    materialFilterOptions: materialFilterOptions,
    selectedAmountProviderLabel: _selectedFilterLabel(
      providerFilterOptions,
      selectedAmountProviderId,
    ),
    selectedWeightMaterialLabel: _selectedFilterLabel(
      materialFilterOptions,
      selectedWeightMaterialId,
    ),
    selectedAvgPriceMaterialLabel: _selectedFilterLabel(
      materialFilterOptions,
      selectedAvgPriceMaterialId,
    ),
  );
}

_ComprasMonthAggregate _aggregateMonth(List<ComprasTicketRecord> rows) {
  final totalAmount = rows.fold<double>(0, (sum, row) => sum + row.amount);
  final totalWeight = rows.fold<double>(
    0,
    (sum, row) => sum + row.payableWeight,
  );
  final providerCount = rows.map((row) => row.providerId).toSet().length;
  final materialCount = rows.map((row) => row.materialId).toSet().length;
  return _ComprasMonthAggregate(
    totalAmount: totalAmount,
    totalWeight: totalWeight,
    avgPrice: totalWeight <= 0.009 ? 0 : totalAmount / totalWeight,
    ticketCount: rows.length,
    providerCount: providerCount,
    materialCount: materialCount,
  );
}

List<_DashboardFilterOption> _buildFilterOptions({
  required List<ComprasTicketRecord> rows,
  required String Function(ComprasTicketRecord row) idFor,
  required String Function(ComprasTicketRecord row) labelFor,
}) {
  final seen = <String, String>{};
  for (final row in rows) {
    final id = idFor(row).trim();
    final label = labelFor(row).trim();
    if (id.isEmpty || label.isEmpty) continue;
    seen.putIfAbsent(id, () => label);
  }
  final options = seen.entries
      .map((entry) => _DashboardFilterOption(id: entry.key, label: entry.value))
      .toList(growable: false);
  options.sort((a, b) => a.label.compareTo(b.label));
  return options;
}

List<ComprasTicketRecord> _filterTicketsByProvider(
  List<ComprasTicketRecord> rows,
  String? providerId,
) {
  if (providerId == null || providerId.isEmpty) return rows;
  return rows
      .where((row) => row.providerId == providerId)
      .toList(growable: false);
}

List<ComprasTicketRecord> _filterTicketsByMaterial(
  List<ComprasTicketRecord> rows,
  String? materialId,
) {
  if (materialId == null || materialId.isEmpty) return rows;
  return rows
      .where((row) => row.materialId == materialId)
      .toList(growable: false);
}

String? _selectedFilterLabel(
  List<_DashboardFilterOption> options,
  String? selectedId,
) {
  if (selectedId == null || selectedId.isEmpty) return null;
  for (final option in options) {
    if (option.id == selectedId) return option.label;
  }
  return null;
}

List<_ComprasBreakdownRow> _buildBreakdownRows({
  required List<ComprasTicketRecord> rows,
  required String Function(ComprasTicketRecord row) labelFor,
  required double totalAmount,
}) {
  final grouped = <String, List<ComprasTicketRecord>>{};
  for (final row in rows) {
    final label = labelFor(row).trim();
    if (label.isEmpty) continue;
    grouped.putIfAbsent(label, () => <ComprasTicketRecord>[]).add(row);
  }
  final result =
      grouped.entries
          .map((entry) {
            final amount = entry.value.fold<double>(
              0,
              (sum, row) => sum + row.amount,
            );
            final weight = entry.value.fold<double>(
              0,
              (sum, row) => sum + row.payableWeight,
            );
            return _ComprasBreakdownRow(
              label: entry.key,
              amount: amount,
              weight: weight,
              avgPrice: weight <= 0.009 ? 0 : amount / weight,
              share: totalAmount <= 0.009 ? 0 : (amount / totalAmount) * 100,
            );
          })
          .toList(growable: false)
        ..sort((a, b) => b.amount.compareTo(a.amount));
  return result;
}

double _weightedAveragePrice(List<ComprasTicketRecord> rows) {
  final totalWeight = rows.fold<double>(
    0,
    (sum, row) => sum + row.payableWeight,
  );
  final totalAmount = rows.fold<double>(0, (sum, row) => sum + row.amount);
  if (totalWeight <= 0.009) return 0;
  return totalAmount / totalWeight;
}

String _kg(double value) => '${formatDecimal(value, decimals: 2)} kg';

String _changeLine({
  required double current,
  required double previous,
  required String suffix,
}) {
  if (previous.abs() < 0.0001) {
    if (current.abs() < 0.0001) return 'Sin variación relevante';
    return 'Sin base previa · $suffix';
  }
  final delta = ((current - previous) / previous) * 100;
  final sign = delta >= 0 ? '+' : '';
  return '$sign${formatDecimal(delta, decimals: 1)}% $suffix';
}
