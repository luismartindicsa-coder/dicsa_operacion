import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/services_visual_mode.dart';

enum GerenciaOperationalViewerMenuDestination {
  dashboard,
  maintenance,
  purchaseOrders,
}

class GerenciaOperationalViewerSideMenu extends StatelessWidget {
  final VoidCallback closeMenu;
  final GerenciaOperationalViewerMenuDestination currentDestination;
  final Future<void> Function() onGoToGerenciaDashboard;
  final Future<void> Function()? onGoToMaintenance;
  final Future<void> Function()? onGoToPurchaseOrders;

  const GerenciaOperationalViewerSideMenu({
    super.key,
    required this.closeMenu,
    required this.currentDestination,
    required this.onGoToGerenciaDashboard,
    this.onGoToMaintenance,
    this.onGoToPurchaseOrders,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ServicesVisualPalette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaQuery = MediaQuery.of(context);
        final fallbackMaxHeight =
            (mediaQuery.size.height -
                    mediaQuery.padding.top -
                    mediaQuery.padding.bottom -
                    112)
                .clamp(320.0, mediaQuery.size.height)
                .toDouble();
        final panelMaxHeight =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : fallbackMaxHeight;

        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: panelMaxHeight),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.menuSurface,
                    gradient: palette.menuPanelGradient,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: palette.logisticsSilver
                          ? palette.border.withValues(alpha: 0.92)
                          : Colors.white.withValues(alpha: 0.14),
                    ),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 26,
                        color: palette.deepShadow,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ScrollConfiguration(
                    behavior: const MaterialScrollBehavior().copyWith(
                      scrollbars: false,
                    ),
                    child: SingleChildScrollView(
                      primary: false,
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Operacion desde Gerencia',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: palette.menuText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Accesos de consulta para OT y compras OT',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: palette.menuTextMuted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _GerenciaViewerMenuHintCard(
                            icon: Icons.keyboard_return_rounded,
                            message:
                                'Al salir de estas pantallas vuelves al dashboard de Gerencia.',
                          ),
                          const SizedBox(height: 16),
                          _GerenciaViewerMenuSectionHeader(text: 'Navegacion'),
                          const SizedBox(height: 10),
                          _GerenciaViewerMenuTile(
                            icon: Icons.space_dashboard_rounded,
                            title: 'Dashboard Gerencia',
                            active:
                                currentDestination ==
                                GerenciaOperationalViewerMenuDestination
                                    .dashboard,
                            emphasize: true,
                            onTap: () => _handleTap(onGoToGerenciaDashboard),
                          ),
                          const SizedBox(height: 8),
                          _GerenciaViewerMenuTile(
                            icon: Icons.assignment_outlined,
                            title: 'Ordenes de trabajo',
                            active:
                                currentDestination ==
                                GerenciaOperationalViewerMenuDestination
                                    .maintenance,
                            onTap: onGoToMaintenance == null
                                ? null
                                : () => _handleTap(onGoToMaintenance!),
                          ),
                          const SizedBox(height: 8),
                          _GerenciaViewerMenuTile(
                            icon: Icons.shopping_cart_checkout_rounded,
                            title: 'Compras OT',
                            active:
                                currentDestination ==
                                GerenciaOperationalViewerMenuDestination
                                    .purchaseOrders,
                            onTap: onGoToPurchaseOrders == null
                                ? null
                                : () => _handleTap(onGoToPurchaseOrders!),
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
      },
    );
  }

  Future<void> _handleTap(Future<void> Function() action) async {
    closeMenu();
    await action();
  }
}

class _GerenciaViewerMenuHintCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _GerenciaViewerMenuHintCard({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ServicesVisualPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: palette.menuSoftFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: palette.logisticsSilver
              ? palette.border.withValues(alpha: 0.74)
              : Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: palette.menuText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: palette.menuTextMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GerenciaViewerMenuSectionHeader extends StatelessWidget {
  final String text;

  const _GerenciaViewerMenuSectionHeader({required this.text});

  @override
  Widget build(BuildContext context) {
    final palette = ServicesVisualPalette.of(context);
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: palette.menuTextMuted,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: palette.logisticsSilver
                ? palette.divider.withValues(alpha: 0.65)
                : Colors.white.withValues(alpha: 0.14),
          ),
        ),
      ],
    );
  }
}

class _GerenciaViewerMenuTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool active;
  final bool emphasize;
  final Future<void> Function()? onTap;

  const _GerenciaViewerMenuTile({
    required this.icon,
    required this.title,
    this.active = false,
    this.emphasize = false,
    this.onTap,
  });

  @override
  State<_GerenciaViewerMenuTile> createState() =>
      _GerenciaViewerMenuTileState();
}

class _GerenciaViewerMenuTileState extends State<_GerenciaViewerMenuTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = ServicesVisualPalette.of(context);
    final enabled = widget.onTap != null;
    final highlighted =
        widget.active || widget.emphasize || (enabled && _hovered);
    final gradient = widget.emphasize ? palette.menuEmphasisGradient : null;
    final foregroundColor = widget.active || enabled
        ? palette.menuText
        : palette.menuTextMuted;

    return MouseRegion(
      onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: enabled ? (_) => setState(() => _hovered = false) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? () => widget.onTap!() : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            gradient: highlighted ? gradient : null,
            color: highlighted
                ? (gradient == null ? palette.menuSoftFillActive : null)
                : palette.menuSoftFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlighted
                  ? (palette.logisticsSilver
                        ? palette.border.withValues(alpha: 0.95)
                        : Colors.white.withValues(alpha: 0.28))
                  : (palette.logisticsSilver
                        ? palette.border.withValues(alpha: 0.72)
                        : Colors.white.withValues(alpha: 0.18)),
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 22, color: foregroundColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: foregroundColor,
                  ),
                ),
              ),
              if (widget.active)
                Icon(
                  Icons.check_circle_rounded,
                  color: palette.logisticsSilver
                      ? palette.icon
                      : const Color(0xFF68F8C6),
                )
              else
                Icon(Icons.chevron_right_rounded, color: palette.menuChevron),
            ],
          ),
        ),
      ),
    );
  }
}
