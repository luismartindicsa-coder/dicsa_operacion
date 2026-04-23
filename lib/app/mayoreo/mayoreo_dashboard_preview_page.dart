import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_access.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/number_formatters.dart';
import 'mayoreo_catalog_page.dart';
import 'mayoreo_price_adjustments_page.dart';
import 'mayoreo_sales_report_page.dart';
import 'mayoreo_theme.dart';

class MayoreoDashboardPreviewPage extends StatefulWidget {
  final bool instantOpen;

  const MayoreoDashboardPreviewPage({super.key, this.instantOpen = false});

  @override
  State<MayoreoDashboardPreviewPage> createState() =>
      _MayoreoDashboardPreviewPageState();
}

class _MayoreoDashboardPreviewPageState
    extends State<MayoreoDashboardPreviewPage> {
  bool _menuOpen = false;
  bool _canReturnToDirection = false;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveNavigationAccess());
  }

  Future<void> _resolveNavigationAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(() {
      _canReturnToDirection = AuthAccess.isDirectionRole(profile);
    });
  }

  Future<void> _openDirectionDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openCatalog() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MayoreoCatalogPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openPriceAdjustments() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MayoreoPriceAdjustmentsPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openSalesReports() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MayoreoSalesReportPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  void _showStub(String label) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$label quedará conectado en la siguiente fase de Mayoreo.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleNavigationAction(String label) {
    switch (label) {
      case 'Dashboard Dirección':
        unawaited(_openDirectionDashboard());
        return;
      case 'Dashboard Mayoreo':
        if (_menuOpen) setState(() => _menuOpen = false);
        return;
      case 'Ventas Mayoreo':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openSalesReports());
        return;
      case 'Catálogo':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openCatalog());
        return;
      case 'Ajuste de precios':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openPriceAdjustments());
        return;
      default:
        if (_menuOpen) setState(() => _menuOpen = false);
        _showStub(label);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AreaThemeScope(
      tokens: mayoreoAreaTokens,
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
          background: const _MayoreoPreviewBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 8,
          padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
          leadingBuilder: (_, _) => _MayoreoHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegación',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, _) => const _MayoreoHeaderBrand(),
          trailingBuilder: (_, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MayoreoHeaderButton(
                label: 'Pendientes',
                icon: Icons.notifications_none_rounded,
                onTap: () async {},
              ),
              const SizedBox(width: 10),
              _MayoreoHeaderButton(
                label: 'Reportes',
                icon: Icons.assessment_outlined,
                onTap: () async {},
              ),
              const SizedBox(width: 10),
              _MayoreoHeaderButton(
                label: 'Cerrar sesión',
                icon: Icons.logout_rounded,
                onTap: () async {},
              ),
            ],
          ),
          child: Stack(
            children: [
              _MayoreoPreviewBody(
                onOpenCatalog: _openCatalog,
                onOpenPriceAdjustments: _openPriceAdjustments,
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
                  child: _MayoreoSidePanel(
                    canReturnToDirection: _canReturnToDirection,
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

class _MayoreoPreviewBackground extends StatelessWidget {
  const _MayoreoPreviewBackground();

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tokens.surfaceTint,
                const Color(0xFFFFF1B8),
                tokens.accent.withValues(alpha: 0.34),
              ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: -260,
          top: -130,
          child: _backgroundCircle(
            760,
            LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.88),
                const Color(0xFFFFED9C),
              ],
            ),
          ),
        ),
        Positioned(
          right: -180,
          top: -70,
          child: _backgroundCircle(
            580,
            LinearGradient(
              colors: [
                const Color(0xFFFFE94A).withValues(alpha: 0.78),
                const Color(0xFFF9A411).withValues(alpha: 0.18),
              ],
            ),
          ),
        ),
        Positioned(
          left: 20,
          bottom: -260,
          child: _backgroundCircle(
            640,
            LinearGradient(
              colors: [
                const Color(0xFFF88C12).withValues(alpha: 0.22),
                tokens.primarySoft.withValues(alpha: 0.88),
              ],
            ),
          ),
        ),
        Positioned(
          right: -105,
          bottom: -120,
          child: IgnorePointer(
            child: Container(
              width: 320,
              height: 500,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(220),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFFFE900).withValues(alpha: 0.90),
                    const Color(0xFFF5A10C).withValues(alpha: 0.86),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _backgroundCircle(double diameter, Gradient gradient) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: gradient,
          boxShadow: [
            BoxShadow(
              blurRadius: diameter * 0.10,
              spreadRadius: diameter * 0.015,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ],
        ),
        child: SizedBox(width: diameter, height: diameter),
      ),
    );
  }
}

class _MayoreoHeaderBrand extends StatelessWidget {
  const _MayoreoHeaderBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.46)),
            boxShadow: [
              BoxShadow(
                color: mayoreoAreaTokens.glow.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Center(child: DicsaLogoD(size: 36, progress: 1)),
        ),
        const SizedBox(width: 14),
        const Text(
          'Dashboard Mayoreo',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: kMayoreoInk,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _MayoreoPreviewBody extends StatelessWidget {
  final Future<void> Function() onOpenCatalog;
  final Future<void> Function() onOpenPriceAdjustments;

  const _MayoreoPreviewBody({
    required this.onOpenCatalog,
    required this.onOpenPriceAdjustments,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 56, right: 2, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MayoreoActionTopBar(
                onOpenCatalog: onOpenCatalog,
                onOpenPriceAdjustments: onOpenPriceAdjustments,
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width >= 1480
                      ? 5
                      : width >= 1160
                      ? 3
                      : width >= 820
                      ? 2
                      : 1;
                  const spacing = 16.0;
                  final cardWidth =
                      (width - ((columns - 1) * spacing)) / columns;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      _MayoreoMetricCard(
                        width: cardWidth,
                        icon: Icons.receipt_long_rounded,
                        title: 'Facturas pendientes',
                        value: '14',
                        detail: 'Pendientes por ser pagadas',
                        accent: const Color(0xFFF39C12),
                      ),
                      _MayoreoMetricCard(
                        width: cardWidth,
                        icon: Icons.request_page_rounded,
                        title: 'Cheques pendientes',
                        value: '6',
                        detail: 'Pendientes por ser cambiados',
                        accent: const Color(0xFFE3B208),
                      ),
                      _MayoreoMetricCard(
                        width: cardWidth,
                        icon: Icons.link_rounded,
                        title: 'Reportes pendientes',
                        value: '9',
                        detail: 'Pendientes por relacionar',
                        accent: const Color(0xFFC78A00),
                      ),
                      _MayoreoMetricCard(
                        width: cardWidth,
                        icon: Icons.arrow_downward_rounded,
                        title: 'Entrada de efectivo',
                        value: _money(184500),
                        detail: 'Mock de ingresos del día',
                        accent: const Color(0xFF5A8466),
                      ),
                      _MayoreoMetricCard(
                        width: cardWidth,
                        icon: Icons.arrow_upward_rounded,
                        title: 'Salida de efectivo',
                        value: _money(96200),
                        detail: 'Mock de egresos del día',
                        accent: const Color(0xFF8A5E12),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              const _MayoreoInsightGrid(),
            ],
          ),
        ),
      ),
    );
  }
}

class _MayoreoActionTopBar extends StatelessWidget {
  final Future<void> Function() onOpenCatalog;
  final Future<void> Function() onOpenPriceAdjustments;

  const _MayoreoActionTopBar({
    required this.onOpenCatalog,
    required this.onOpenPriceAdjustments,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MayoreoHeroActionIconButton(
                tooltip: 'Abrir catálogo',
                icon: Icons.inventory_2_outlined,
                filled: true,
                onTap: () async => onOpenCatalog(),
              ),
              _MayoreoHeroActionIconButton(
                tooltip: 'Ajuste de precios',
                icon: Icons.tune_rounded,
                onTap: () async => onOpenPriceAdjustments(),
              ),
              _MayoreoHeroActionIconButton(
                tooltip: 'Flujo de efectivo',
                icon: Icons.account_balance_wallet_outlined,
                onTap: () async {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.44),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: tokens.primarySoft.withValues(alpha: 0.30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: tokens.primaryStrong.withValues(alpha: 0.12),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Total de efectivo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: tokens.primaryStrong.withValues(alpha: 0.84),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _money(438900),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1F262B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Mock: efectivo actual + entradas - salidas + cuenta El Palomar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6A6966),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MayoreoHeroActionIconButton extends StatefulWidget {
  final String tooltip;
  final IconData icon;
  final Future<void> Function() onTap;
  final bool filled;

  const _MayoreoHeroActionIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  State<_MayoreoHeroActionIconButton> createState() =>
      _MayoreoHeroActionIconButtonState();
}

class _MayoreoHeroActionIconButtonState
    extends State<_MayoreoHeroActionIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final background = widget.filled
        ? tokens.primaryStrong.withValues(alpha: 0.96)
        : Colors.white.withValues(alpha: 0.58);
    final iconColor = widget.filled ? Colors.white : tokens.primaryStrong;
    final borderColor = widget.filled
        ? tokens.primaryStrong.withValues(alpha: 0.18)
        : tokens.primaryStrong.withValues(alpha: 0.16);

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          scale: _hovered ? 1.05 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.identity()
              ..translateByDouble(0, _hovered ? -2 : 0, 0, 1),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: tokens.primaryStrong.withValues(
                    alpha: _hovered ? 0.16 : 0.08,
                  ),
                  blurRadius: _hovered ? 20 : 12,
                  offset: Offset(0, _hovered ? 10 : 6),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () async => widget.onTap(),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(widget.icon, color: iconColor, size: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MayoreoMetricCard extends StatefulWidget {
  final double width;
  final IconData icon;
  final String title;
  final String value;
  final String detail;
  final Color accent;

  const _MayoreoMetricCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    required this.accent,
  });

  @override
  State<_MayoreoMetricCard> createState() => _MayoreoMetricCardState();
}

class _MayoreoMetricCardState extends State<_MayoreoMetricCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          scale: _hovered ? 1.008 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.identity()
              ..translateByDouble(0.0, _hovered ? -3.0 : 0.0, 0.0, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: _hovered
                    ? [
                        BoxShadow(
                          color: widget.accent.withValues(alpha: 0.16),
                          blurRadius: 26,
                          offset: const Offset(0, 12),
                        ),
                      ]
                    : const [],
              ),
              child: ContractGlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: widget.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(widget.icon, color: widget.accent),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF5A5552),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.value,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1F262B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.detail,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6A6966),
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

class _MayoreoInsightGrid extends StatelessWidget {
  const _MayoreoInsightGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 980;
        final topRow = stacked
            ? const Column(
                children: [
                  _MayoreoInsightCard(
                    child: _DashboardListBlock(
                      title: 'Pendientes por atender',
                      subtitle: 'Lo inmediato para liberar operación comercial',
                      items: [
                        _DashboardListItem(
                          label: 'Facturas por pagar',
                          value: '14',
                        ),
                        _DashboardListItem(
                          label: 'Cheques por cambiar',
                          value: '6',
                        ),
                        _DashboardListItem(
                          label: 'Reportes por relacionar',
                          value: '9',
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  _MayoreoInsightCard(
                    child: _DashboardListBlock(
                      title: 'Precios principales de chatarra',
                      subtitle: 'Mock inicial para definir lectura comercial',
                      items: [
                        _DashboardListItem(label: 'CH MIXTA', value: '\$4,350'),
                        _DashboardListItem(
                          label: 'ALUMINIO',
                          value: '\$26,800',
                        ),
                        _DashboardListItem(label: 'COBRE', value: '\$118,000'),
                        _DashboardListItem(label: 'FIERRO', value: '\$5,120'),
                      ],
                    ),
                  ),
                ],
              )
            : const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _MayoreoInsightCard(
                      child: _DashboardListBlock(
                        title: 'Pendientes por atender',
                        subtitle:
                            'Lo inmediato para liberar operación comercial',
                        items: [
                          _DashboardListItem(
                            label: 'Facturas por pagar',
                            value: '14',
                          ),
                          _DashboardListItem(
                            label: 'Cheques por cambiar',
                            value: '6',
                          ),
                          _DashboardListItem(
                            label: 'Reportes por relacionar',
                            value: '9',
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _MayoreoInsightCard(
                      child: _DashboardListBlock(
                        title: 'Precios principales de chatarra',
                        subtitle: 'Mock inicial para definir lectura comercial',
                        items: [
                          _DashboardListItem(
                            label: 'CH MIXTA',
                            value: '\$4,350',
                          ),
                          _DashboardListItem(
                            label: 'ALUMINIO',
                            value: '\$26,800',
                          ),
                          _DashboardListItem(
                            label: 'COBRE',
                            value: '\$118,000',
                          ),
                          _DashboardListItem(label: 'FIERRO', value: '\$5,120'),
                        ],
                      ),
                    ),
                  ),
                ],
              );
        return Column(
          children: [
            topRow,
            const SizedBox(height: 16),
            const _MayoreoInsightCard(
              child: _DashboardListBlock(
                title: 'Caja y cuentas',
                subtitle: 'Bloque mock para flujo de efectivo y cuentas clave',
                items: [
                  _DashboardListItem(
                    label: 'Entrada de efectivo',
                    value: '\$184,500',
                  ),
                  _DashboardListItem(
                    label: 'Salida de efectivo',
                    value: '\$96,200',
                  ),
                  _DashboardListItem(
                    label: 'Cuenta El Palomar',
                    value: 'Pendiente de definición',
                  ),
                  _DashboardListItem(
                    label: 'Efectivo por relacionar',
                    value: '\$42,300',
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MayoreoInsightCard extends StatefulWidget {
  final Widget child;

  const _MayoreoInsightCard({required this.child});

  @override
  State<_MayoreoInsightCard> createState() => _MayoreoInsightCardState();
}

class _MayoreoInsightCardState extends State<_MayoreoInsightCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: _hovered ? 1.004 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()
            ..translateByDouble(0.0, _hovered ? -3.0 : 0.0, 0.0, 1.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: tokens.primaryStrong.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ]
                  : const [],
            ),
            child: ContractGlassCard(
              padding: const EdgeInsets.all(18),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardListBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_DashboardListItem> items;

  const _DashboardListBlock({
    required this.title,
    required this.subtitle,
    required this.items,
  });

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
            color: kMayoreoInk,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: kMayoreoMutedInk,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DashboardListRow(item: item),
          ),
        ),
      ],
    );
  }
}

class _DashboardListItem {
  final String label;
  final String value;

  const _DashboardListItem({required this.label, required this.value});
}

class _DashboardListRow extends StatelessWidget {
  final _DashboardListItem item;

  const _DashboardListRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.88),
            tokens.badgeBackground.withValues(alpha: 0.70),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.border.withValues(alpha: 0.84)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: kMayoreoInk,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            item.value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: tokens.primaryStrong,
            ),
          ),
        ],
      ),
    );
  }
}

String _money(num value) => formatMoney(value);

class _MayoreoHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;

  const _MayoreoHeaderButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
  });

  @override
  State<_MayoreoHeaderButton> createState() => _MayoreoHeaderButtonState();
}

class _MayoreoHeaderButtonState extends State<_MayoreoHeaderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final enabled = widget.onTap != null || widget.onTapSync != null;
    final highlighted = enabled && _hovered;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: highlighted ? 1.026 : 1,
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
              transform: Matrix4.translationValues(
                0,
                highlighted ? -2.5 : 0,
                0,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: highlighted ? 0.32 : 0.22),
                    tokens.surfaceTint.withValues(
                      alpha: highlighted ? 0.42 : 0.26,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: highlighted
                      ? Colors.white.withValues(alpha: 0.76)
                      : Colors.white.withValues(alpha: 0.48),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: highlighted ? 28 : 16,
                    color: Colors.black.withValues(
                      alpha: highlighted ? 0.16 : 0.08,
                    ),
                    offset: Offset(0, highlighted ? 14 : 8),
                  ),
                  BoxShadow(
                    blurRadius: highlighted ? 20 : 10,
                    color: tokens.glow.withValues(
                      alpha: highlighted ? 0.12 : 0.05,
                    ),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, color: tokens.primaryStrong),
                  const SizedBox(width: 10),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: tokens.primaryStrong,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
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

class _MayoreoSidePanel extends StatelessWidget {
  final bool canReturnToDirection;
  final ValueChanged<String> onNavigate;

  const _MayoreoSidePanel({
    required this.canReturnToDirection,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ContractGlassCard(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Mayoreo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
              const SizedBox(height: 16),
              if (canReturnToDirection) ...[
                _MayoreoNavItem(
                  icon: Icons.arrow_back_rounded,
                  title: 'Volver a Dirección',
                  onTapSync: () => onNavigate('Dashboard Dirección'),
                ),
                const SizedBox(height: 10),
              ],
              const _MayoreoSectionHeader(label: 'MENU'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.primarySoft.withValues(alpha: 0.34),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: tokens.primaryStrong.withValues(alpha: 0.14),
                  ),
                ),
                child: Column(
                  children: [
                    _MayoreoNavItem(
                      icon: Icons.point_of_sale_rounded,
                      title: 'Ventas',
                      subtitle: 'Seguimiento de pedidos y cierre',
                      onTapSync: () => onNavigate('Ventas Mayoreo'),
                    ),
                    const SizedBox(height: 8),
                    _MayoreoNavItem(
                      icon: Icons.price_check_rounded,
                      title: 'Catálogo',
                      subtitle: 'Empresas, materiales y precios',
                      onTapSync: () => onNavigate('Catálogo'),
                    ),
                    const SizedBox(height: 8),
                    _MayoreoNavItem(
                      icon: Icons.request_quote_rounded,
                      title: 'Ajuste de precios',
                      subtitle: 'Listas, vigentes y ajustes',
                      onTapSync: () => onNavigate('Ajuste de precios'),
                    ),
                    const SizedBox(height: 8),
                    _MayoreoNavItem(
                      icon: Icons.local_shipping_rounded,
                      title: 'Rutas',
                      subtitle: 'Planeación de embarques',
                      onTapSync: () => onNavigate('Rutas'),
                    ),
                    const SizedBox(height: 8),
                    _MayoreoNavItem(
                      icon: Icons.assessment_rounded,
                      title: 'Reportes',
                      subtitle: 'Indicadores, cortes y resumen',
                      onTapSync: () => onNavigate('Reportes'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _MayoreoSectionHeader(label: 'ACCESOS'),
              const SizedBox(height: 8),
              if (canReturnToDirection) ...[
                _MayoreoNavItem(
                  icon: Icons.assessment_outlined,
                  title: 'Dashboard Dirección',
                  subtitle: 'Vista ejecutiva multiarea',
                  onTapSync: () => onNavigate('Dashboard Dirección'),
                ),
                const SizedBox(height: 8),
              ],
              const _MayoreoNavItem(
                icon: Icons.space_dashboard_rounded,
                title: 'Dashboard Mayoreo',
                subtitle: 'Vista general del área',
                accented: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MayoreoSectionHeader extends StatelessWidget {
  final String label;

  const _MayoreoSectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
            color: tokens.badgeText,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: tokens.primarySoft.withValues(alpha: 0.32),
          ),
        ),
      ],
    );
  }
}

class _MayoreoNavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool accented;
  final VoidCallback? onTapSync;

  const _MayoreoNavItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.accented = false,
    this.onTapSync,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTapSync,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: accented ? kMayoreoHeroGradient : kMayoreoPanelGradient,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: accented
                    ? Colors.white.withValues(alpha: 0.72)
                    : Colors.white.withValues(alpha: 0.58),
              ),
              boxShadow: accented
                  ? [
                      BoxShadow(
                        color: mayoreoAreaTokens.glow.withValues(alpha: 0.20),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: accented ? Colors.white : tokens.primaryStrong,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: accented ? Colors.white : tokens.primaryStrong,
                        ),
                      ),
                      if (hasSubtitle) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: accented
                                ? Colors.white.withValues(alpha: 0.92)
                                : tokens.badgeText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!accented) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: tokens.badgeText,
                    size: 22,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
