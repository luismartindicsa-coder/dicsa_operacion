import 'package:flutter/material.dart';

import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import 'menudeo_theme.dart';

/// El orden y las posiciones son comunes a todas las páginas de Menudeo.
/// Los accesos de Dirección conservan la restricción del menú original.
enum MenudeoDestination {
  purchases,
  sales,
  depositsExpenses,
  priceAdjustments,
  catalog,
  cashCuts,
  cashTaxonomy,
  dashboard,
  direction,
  operation,
}

class MenudeoNavigationButton extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onToggle;

  const MenudeoNavigationButton({
    super.key,
    required this.isOpen,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) => _NavigationHeaderButton(
    label: isOpen ? 'Cerrar panel' : 'Navegación',
    icon: isOpen ? Icons.close_rounded : Icons.menu_rounded,
    onTapSync: onToggle,
  );
}

class MenudeoNavigationPanel extends StatelessWidget {
  final MenudeoDestination currentDestination;
  final bool canReturnToDirection;
  final bool canOpenCashTaxonomy;
  final ValueChanged<MenudeoDestination> onNavigate;
  final ScrollController? scrollController;

  const MenudeoNavigationPanel({
    super.key,
    required this.currentDestination,
    required this.canReturnToDirection,
    required this.canOpenCashTaxonomy,
    required this.onNavigate,
    this.scrollController,
  });

  Widget _item(
    MenudeoDestination destination,
    IconData icon,
    String title,
    String subtitle, {
    bool accent = false,
  }) => Semantics(
    key: ValueKey('menudeo-nav-${destination.name}'),
    selected: currentDestination == destination,
    child: _NavigationPanelItem(
      icon: icon,
      title: title,
      subtitle: subtitle,
      isActive: currentDestination == destination,
      isAccent: accent,
      onTapSync: () => onNavigate(destination),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ContractGlassCard(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: SingleChildScrollView(
          controller: scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Menudeo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
              const SizedBox(height: 16),
              if (canReturnToDirection) ...[
                _NavigationPanelItem(
                  icon: Icons.arrow_back_rounded,
                  title: 'Volver a Dirección',
                  onTapSync: () => onNavigate(MenudeoDestination.direction),
                ),
                const SizedBox(height: 10),
              ],
              const _NavigationSectionHeader(label: 'MENU'),
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
                    _item(
                      MenudeoDestination.purchases,
                      Icons.receipt_long_rounded,
                      'Compras',
                      'Tickets virtuales de compra',
                    ),
                    const SizedBox(height: 8),
                    _item(
                      MenudeoDestination.sales,
                      Icons.point_of_sale_rounded,
                      'Ventas',
                      'Tickets virtuales de venta',
                    ),
                    const SizedBox(height: 8),
                    _item(
                      MenudeoDestination.depositsExpenses,
                      Icons.account_balance_wallet_rounded,
                      'Depósitos y gastos',
                      'Vouchers de caja y egresos',
                    ),
                    const SizedBox(height: 8),
                    _item(
                      MenudeoDestination.priceAdjustments,
                      Icons.auto_graph_rounded,
                      'Ajuste de precios',
                      'Cambios e historial',
                    ),
                    const SizedBox(height: 8),
                    _item(
                      MenudeoDestination.catalog,
                      Icons.price_check_rounded,
                      'Catálogo',
                      'Materiales, grupos y precios',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _NavigationSectionHeader(label: 'ACCESOS'),
              const SizedBox(height: 8),
              _item(
                MenudeoDestination.dashboard,
                Icons.space_dashboard_rounded,
                'Dashboard Menudeo',
                'Vista general del área',
                accent: true,
              ),
              if (canReturnToDirection) ...[
                const SizedBox(height: 8),
                _item(
                  MenudeoDestination.cashCuts,
                  Icons.inventory_2_rounded,
                  'Corte de caja',
                  'Historial y revisión',
                ),
              ],
              if (canOpenCashTaxonomy) ...[
                const SizedBox(height: 8),
                _item(
                  MenudeoDestination.cashTaxonomy,
                  Icons.tune_rounded,
                  'Catálogo efectivo',
                  'Conceptos y parámetros',
                ),
              ],
              if (canReturnToDirection) ...[
                const SizedBox(height: 8),
                _item(
                  MenudeoDestination.direction,
                  Icons.assessment_outlined,
                  'Dashboard Dirección',
                  'Vista ejecutiva multiarea',
                ),
                const SizedBox(height: 8),
                _item(
                  MenudeoDestination.operation,
                  Icons.precision_manufacturing_rounded,
                  'Dashboard Operación',
                  'Patio, inventario y servicios',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationSectionHeader extends StatelessWidget {
  final String label;

  const _NavigationSectionHeader({required this.label});

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

class _NavigationPanelItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool isActive;
  final bool isAccent;
  final VoidCallback? onTapSync;

  const _NavigationPanelItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.isActive = false,
    this.isAccent = false,
    this.onTapSync,
  });

  @override
  State<_NavigationPanelItem> createState() => _NavigationPanelItemState();
}

class _NavigationPanelItemState extends State<_NavigationPanelItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final active = widget.isActive;
    final hasSubtitle =
        widget.subtitle != null && widget.subtitle!.trim().isNotEmpty;
    final border = widget.isAccent
        ? Colors.white.withValues(alpha: 0.72)
        : active
        ? tokens.primaryStrong.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: _hovered ? 0.62 : 0.58);
    final shadowColor = widget.isAccent
        ? kMenudeoPanelShadow.withValues(alpha: 0.24)
        : active
        ? kMenudeoPanelShadow.withValues(alpha: 0.18)
        : kMenudeoPanelShadow.withValues(alpha: _hovered ? 0.14 : 0.12);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: _NavigationTapSurface(
        onTap: widget.onTapSync,
        scale: _hovered ? 1.012 : 1,
        duration: const Duration(milliseconds: 140),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: widget.isAccent
                ? kMenudeoPanelAccentGradient
                : active
                ? kMenudeoPanelHighlightGradient
                : kMenudeoPanelGradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: widget.isAccent ? 22 : (_hovered ? 18 : 16),
                offset: Offset(0, _hovered ? 12 : 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: (widget.isAccent || active)
                            ? Colors.white
                            : tokens.primaryStrong,
                      ),
                    ),
                    if (hasSubtitle) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: (widget.isAccent || active)
                              ? Colors.white.withValues(alpha: 0.92)
                              : tokens.badgeText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (active) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.check_circle_rounded,
                  color: tokens.primarySoft,
                  size: 22,
                ),
              ] else ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: widget.isAccent ? Colors.white : tokens.primaryStrong,
                  size: 22,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTapSync;

  const _NavigationHeaderButton({
    required this.label,
    required this.icon,
    this.onTapSync,
  });

  @override
  State<_NavigationHeaderButton> createState() =>
      _NavigationHeaderButtonState();
}

class _NavigationHeaderButtonState extends State<_NavigationHeaderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final enabled = widget.onTapSync != null;
    final highlighted = enabled && _hovered;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: _NavigationTapSurface(
        onTap: widget.onTapSync,
        scale: highlighted ? 1.026 : 1,
        duration: const Duration(milliseconds: 180),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, highlighted ? -2.5 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: highlighted ? 0.30 : 0.22),
                tokens.surfaceTint.withValues(alpha: highlighted ? 0.34 : 0.24),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: highlighted
                  ? Colors.white.withValues(alpha: 0.70)
                  : Colors.white.withValues(alpha: 0.46),
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
                color: tokens.primaryStrong.withValues(
                  alpha: highlighted ? 0.10 : 0.04,
                ),
                offset: const Offset(0, 0),
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
    );
  }
}

/// La zona de clic permanece fija y contiene toda la elevación del hover.
/// El margen se descuenta del padding visual para conservar el layout.
class _NavigationTapSurface extends StatelessWidget {
  final VoidCallback? onTap;
  final double scale;
  final Duration duration;
  final Widget child;

  const _NavigationTapSurface({
    required this.onTap,
    required this.scale,
    required this.duration,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: AnimatedScale(
          duration: duration,
          curve: Curves.easeOutCubic,
          scale: scale,
          child: child,
        ),
      ),
    ),
  );
}
