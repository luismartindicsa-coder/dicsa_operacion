import 'dart:ui';

import 'package:flutter/material.dart';

import '../shared/ui_contract_core/theme/contract_tokens.dart';

const ContractAreaTokens finanzasAreaTokens = ContractAreaTokens(
  primary: Color(0xFFFF9A3D),
  primaryStrong: Color(0xFFFF6A1A),
  primarySoft: Color(0xFFFFC58A),
  accent: Color(0xFFFFB36B),
  surfaceTint: Color(0xFF1B1E24),
  border: Color(0xFF8C96A3),
  badgeBackground: Color(0xFF232831),
  badgeText: Color(0xFFD6DCE4),
  glow: Color(0xFFFF7A1F),
  darkGlass: true,
  glassSurface: Color(0x66212731),
  fieldSurface: Color(0xB31A1F27),
  onGlass: Color(0xFFF3F5F7),
);

const LinearGradient kFinanzasHeroGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF1A1D23), Color(0xFF111318), Color(0xFF080A0E)],
);

const LinearGradient kFinanzasPanelGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0x26FFFFFF), Color(0x12FF8C2B), Color(0x14101820)],
);

const LinearGradient kFinanzasAccentGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFF9A3D), Color(0xFFFF6A1A), Color(0xFF2B1308)],
);

const Color kFinanzasInk = Color(0xFFF3F5F7);
const Color kFinanzasMutedInk = Color(0xFFBDC5D0);

class FinanzasAreaNavEntry {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool current;
  final Future<void> Function()? onTap;

  const FinanzasAreaNavEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.current = false,
    this.onTap,
  });
}

class FinanzasGlassPanel extends StatelessWidget {
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

  const FinanzasGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.blurSigma = 22,
    this.fillColor = const Color(0x1410151C),
    this.borderColor = const Color(0x45FFFFFF),
    this.shadowColor = const Color(0x16000000),
    this.edgeHighlightColor = const Color(0xAAFFFFFF),
    this.bevelShadowColor = const Color(0x18000000),
    this.glowColor = const Color(0x22FF8A2B),
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
                const Color(0xFFFF9A3D).withValues(alpha: 0.05),
                const Color(0xFF1A1F27).withValues(alpha: 0.20),
              ],
              stops: const [0.0, 0.34, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                offset: const Offset(0, 8),
                color: shadowColor,
              ),
              BoxShadow(
                blurRadius: 18,
                offset: const Offset(-2, -2),
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
                          const Color(0xFFFFB36B).withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.20, 0.56],
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
                          Colors.white.withValues(alpha: 0.16),
                          Colors.white.withValues(alpha: 0.04),
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
                      boxShadow: [
                        BoxShadow(
                          color: edgeHighlightColor.withValues(alpha: 0.10),
                          blurRadius: 0,
                          spreadRadius: 0.6,
                        ),
                        BoxShadow(
                          color: bevelShadowColor.withValues(alpha: 0.14),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
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

class FinanzasAreaSidePanel extends StatelessWidget {
  final String currentLabel;
  final bool canReturnToDirection;
  final bool canAccessComprasArea;
  final ValueChanged<String> onNavigate;
  final String title;
  final String subtitle;

  const FinanzasAreaSidePanel({
    super.key,
    required this.currentLabel,
    required this.canReturnToDirection,
    required this.canAccessComprasArea,
    required this.onNavigate,
    this.title = 'Navegación Finanzas',
    this.subtitle = 'Módulos del área y accesos habilitados',
  });

  @override
  Widget build(BuildContext context) {
    final executionItems = <FinanzasAreaNavEntry>[
      FinanzasAreaNavEntry(
        icon: Icons.balance_rounded,
        title: 'Centro de pagos',
        subtitle: 'Prioridad, capacidad y ejecución',
        current: currentLabel == 'Centro de pagos',
        onTap: currentLabel == 'Centro de pagos'
            ? null
            : () async => onNavigate('Centro de pagos'),
      ),
      FinanzasAreaNavEntry(
        icon: Icons.account_balance_outlined,
        title: 'Cuentas Bancarias',
        subtitle: 'Entradas, salidas y conciliación',
        current: currentLabel == 'Cuentas Bancarias',
        onTap: currentLabel == 'Cuentas Bancarias'
            ? null
            : () async => onNavigate('Cuentas Bancarias'),
      ),
      FinanzasAreaNavEntry(
        icon: Icons.receipt_long_outlined,
        title: 'Pagos fijos',
        subtitle: 'Compromisos periódicos y calendario',
        current: currentLabel == 'Pagos fijos',
        onTap: currentLabel == 'Pagos fijos'
            ? null
            : () async => onNavigate('Pagos fijos'),
      ),
    ];

    final providerItems = <FinanzasAreaNavEntry>[
      FinanzasAreaNavEntry(
        icon: Icons.view_list_rounded,
        title: 'Cuentas por Proveedor',
        subtitle: 'Facturas, saldo vivo y convenios',
        current: currentLabel == 'Cuentas por Proveedor',
        onTap: currentLabel == 'Cuentas por Proveedor'
            ? null
            : () async => onNavigate('Cuentas por Proveedor'),
      ),
      FinanzasAreaNavEntry(
        icon: Icons.account_balance_rounded,
        title: 'Directorio Empresas',
        subtitle: 'Crédito, contacto y operación',
        current: currentLabel == 'Directorio Empresas',
        onTap: currentLabel == 'Directorio Empresas'
            ? null
            : () async => onNavigate('Directorio Empresas'),
      ),
      FinanzasAreaNavEntry(
        icon: Icons.price_check_rounded,
        title: 'Catálogo Finanzas',
        subtitle: 'Empresas, conceptos y relaciones',
        current: currentLabel == 'Catálogo Finanzas',
        onTap: currentLabel == 'Catálogo Finanzas'
            ? null
            : () async => onNavigate('Catálogo Finanzas'),
      ),
    ];

    final accessItems = <FinanzasAreaNavEntry>[
      FinanzasAreaNavEntry(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Dashboard Finanzas',
        subtitle: 'Flujo, pagos y lectura ejecutiva',
        current: currentLabel == 'Dashboard Finanzas',
        onTap: currentLabel == 'Dashboard Finanzas'
            ? null
            : () async => onNavigate('Dashboard Finanzas'),
      ),
      if (canAccessComprasArea)
        const FinanzasAreaNavEntry(
          icon: Icons.shopping_cart_checkout_rounded,
          title: 'Dashboard Compras',
          subtitle: 'Cruce operativo de compra mayoreo',
        ),
      if (canReturnToDirection)
        const FinanzasAreaNavEntry(
          icon: Icons.space_dashboard_rounded,
          title: 'Dashboard Dirección',
          subtitle: 'Vista ejecutiva multiarea',
        ),
    ];

    return SizedBox(
      width: 320,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: FinanzasGlassPanel(
          borderRadius: BorderRadius.circular(28),
          blurSigma: 30,
          fillColor: const Color(0xFF10151C).withValues(alpha: 0.22),
          borderColor: Colors.white.withValues(alpha: 0.30),
          shadowColor: Colors.black.withValues(alpha: 0.18),
          edgeHighlightColor: Colors.white.withValues(alpha: 0.76),
          bevelShadowColor: Colors.black.withValues(alpha: 0.20),
          glowColor: const Color(0xFFFF8E2C).withValues(alpha: 0.16),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xB8E2E7EF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                _FinanzasSidePanelBlock(
                  icon: Icons.balance_rounded,
                  title: 'Ejecución',
                  children: executionItems,
                ),
                const SizedBox(height: 12),
                _FinanzasSidePanelBlock(
                  icon: Icons.group_work_rounded,
                  title: 'Proveedores',
                  children: providerItems,
                ),
                const SizedBox(height: 12),
                _FinanzasSidePanelBlock(
                  icon: Icons.apps_rounded,
                  title: 'Accesos',
                  children: accessItems
                      .map(
                        (entry) => FinanzasAreaNavEntry(
                          icon: entry.icon,
                          title: entry.title,
                          subtitle: entry.subtitle,
                          current: currentLabel == entry.title,
                          onTap: currentLabel == entry.title
                              ? null
                              : () async => onNavigate(entry.title),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FinanzasSidePanelBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<FinanzasAreaNavEntry> children;

  const _FinanzasSidePanelBlock({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return FinanzasGlassPanel(
      borderRadius: BorderRadius.circular(20),
      blurSigma: 24,
      fillColor: const Color(0xFF151A21).withValues(alpha: 0.18),
      borderColor: Colors.white.withValues(alpha: 0.26),
      shadowColor: Colors.black.withValues(alpha: 0.14),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.66),
      bevelShadowColor: Colors.black.withValues(alpha: 0.18),
      glowColor: const Color(0xFFFF8A2B).withValues(alpha: 0.10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < children.length; i++) ...[
            _FinanzasSidePanelAction(entry: children[i]),
            if (i != children.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _FinanzasSidePanelAction extends StatefulWidget {
  final FinanzasAreaNavEntry entry;

  const _FinanzasSidePanelAction({required this.entry});

  @override
  State<_FinanzasSidePanelAction> createState() =>
      _FinanzasSidePanelActionState();
}

class _FinanzasSidePanelActionState extends State<_FinanzasSidePanelAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.entry.current || _hovered;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: widget.entry.current ? null : widget.entry.onTap,
        child: FinanzasGlassPanel(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          borderRadius: BorderRadius.circular(18),
          blurSigma: 24,
          fillColor: highlighted
              ? const Color(0xFFFF8A2B).withValues(alpha: 0.14)
              : const Color(0xFF171C24).withValues(alpha: 0.14),
          borderColor: Colors.white.withValues(
            alpha: highlighted ? 0.30 : 0.20,
          ),
          shadowColor: Colors.black.withValues(alpha: 0.08),
          edgeHighlightColor: Colors.white.withValues(alpha: 0.70),
          bevelShadowColor: Colors.black.withValues(alpha: 0.14),
          glowColor: highlighted
              ? const Color(0xFFFF8A2B).withValues(alpha: 0.18)
              : const Color(0xFFFF8A2B).withValues(alpha: 0.08),
          child: Row(
            children: [
              Icon(widget.entry.icon, size: 18, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.entry.title,
                      style: const TextStyle(
                        color: kFinanzasInk,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.entry.subtitle,
                      style: const TextStyle(
                        color: kFinanzasMutedInk,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.entry.current)
                Icon(
                  Icons.check_circle_rounded,
                  color: finanzasAreaTokens.primarySoft,
                  size: 20,
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: kFinanzasMutedInk,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class FinanzasAreaBackground extends StatelessWidget {
  const FinanzasAreaBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1D23), Color(0xFF111318), Color(0xFF080A0E)],
            ),
          ),
        ),
        Positioned(
          left: -220,
          top: -140,
          child: _FinanzasBackgroundBlob(
            size: 760,
            colors: [
              Colors.white.withValues(alpha: 0.10),
              const Color(0xFFFFD0A3).withValues(alpha: 0.10),
            ],
          ),
        ),
        Positioned(
          right: -180,
          top: -80,
          child: _FinanzasBackgroundBlob(
            size: 560,
            colors: [
              const Color(0xFFFF7A1F).withValues(alpha: 0.30),
              const Color(0x14090B0F),
            ],
          ),
        ),
        Positioned(
          left: -60,
          bottom: -240,
          child: _FinanzasBackgroundBlob(
            size: 560,
            colors: [const Color(0x22111720), const Color(0x20D0D7E2)],
          ),
        ),
        Positioned(
          right: -100,
          bottom: -130,
          child: IgnorePointer(
            child: Container(
              width: 300,
              height: 520,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(220),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFFF6A1A).withValues(alpha: 0.68),
                    const Color(0xFF14181F).withValues(alpha: 0.94),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FinanzasBackgroundBlob extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _FinanzasBackgroundBlob({required this.size, required this.colors});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: size * 0.10,
              spreadRadius: size * 0.015,
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ],
        ),
        child: SizedBox(width: size, height: size),
      ),
    );
  }
}
