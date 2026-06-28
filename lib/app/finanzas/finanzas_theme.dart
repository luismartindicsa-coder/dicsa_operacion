import 'dart:ui';

import 'package:flutter/material.dart';

import '../shared/dicsa_logo_mark.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_tokens.dart';

const Color kFinanzasBg = Color(0xFF050201);
const Color kFinanzasBgDeep = Color(0xFF0B0301);
const Color kFinanzasBgWarm = Color(0xFF160702);

const Color kFinanzasOrange = Color(0xFFFF7A18);
const Color kFinanzasOrangeElectric = Color(0xFFFF8A00);
const Color kFinanzasOrangeIntense = Color(0xFFFF5A00);
const Color kFinanzasAmberHighlight = Color(0xFFFFA347);
const Color kFinanzasLightGlow = Color(0xFFFFC27C);

const Color kFinanzasInk = Color(0xFFFFF7EF);
const Color kFinanzasMutedInk = Color(0xC7FFEFE0);
const Color kFinanzasSubtleInk = Color(0x8CFFE1CC);

const Color kFinanzasSurfaceGlass = Color(0xB8180903);
const Color kFinanzasSurfaceElevated = Color(0xC62C1005);
const Color kFinanzasSurfaceHover = Color(0x24FF6F18);
const Color kFinanzasSurfaceActive = Color(0x38FF7A18);
const Color kFinanzasBorder = Color(0x3DFF7A18);
const Color kFinanzasBorderHover = Color(0x73FF8A00);
const Color kFinanzasBorderActive = Color(0xB3FF8A00);
const Color kFinanzasGlowSoft = Color(0x47FF7A18);
const Color kFinanzasGlowStrong = Color(0x73FF6600);

const Color kFinanzasPearl = Color(0xFFFFE3C3);
const Color kFinanzasAmber = kFinanzasOrangeElectric;
const Color kFinanzasCopper = kFinanzasOrange;
const Color kFinanzasBurnt = kFinanzasOrangeIntense;
const Color kFinanzasCoral = Color(0xFFFF6610);
const Color kFinanzasSage = Color(0xFFFF7A18);
const Color kFinanzasTaupe = Color(0xFFFF9735);
const Color kFinanzasBronze = Color(0xFFFFAE48);

const Color kFinanzasDialogSurface = kFinanzasBgWarm;
const Color kFinanzasPanelSurface = kFinanzasSurfaceGlass;
const Color kFinanzasPanelSurfaceStrong = kFinanzasSurfaceElevated;
const Color kFinanzasPanelSurfaceSoft = Color(0xA3200B04);
const Color kFinanzasPanelSurfaceSubtle = Color(0x96130502);
const Color kFinanzasPanelSurfaceLight = Color(0xC6341307);
const Color kFinanzasSelectionFill = kFinanzasSurfaceActive;

const ContractAreaTokens finanzasAreaTokens = ContractAreaTokens(
  primary: kFinanzasOrange,
  primaryStrong: kFinanzasOrange,
  primarySoft: Color(0xFFFFA85B),
  accent: kFinanzasOrangeIntense,
  surfaceTint: Color(0xFF351105),
  border: kFinanzasBorderHover,
  badgeBackground: Color(0x99100502),
  badgeText: Color(0xFFFFD7B5),
  glow: kFinanzasOrange,
  darkGlass: true,
  accentDarkGlass: true,
  glassSurface: kFinanzasSurfaceGlass,
  fieldSurface: Color(0xC2140602),
  onGlass: kFinanzasInk,
);

const LinearGradient kFinanzasHeroGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kFinanzasBg, kFinanzasBgDeep, Color(0xFF1A0701)],
);

const LinearGradient kFinanzasPanelGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0x16FF8A00), Color(0x1AFF7A18), Color(0x18FF5A00)],
);

const LinearGradient kFinanzasAccentGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kFinanzasOrangeElectric, kFinanzasOrange, kFinanzasOrangeIntense],
);

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

class FinanzasPageHeaderBrand extends StatelessWidget {
  final String title;

  const FinanzasPageHeaderBrand({super.key, required this.title});

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
          title,
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

class FinanzasPageHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;
  final bool iconOnly;

  const FinanzasPageHeaderButton({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
    this.iconOnly = false,
  });

  @override
  State<FinanzasPageHeaderButton> createState() =>
      _FinanzasPageHeaderButtonState();
}

class _FinanzasPageHeaderButtonState extends State<FinanzasPageHeaderButton> {
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
                    kFinanzasOrange.withValues(
                      alpha: highlighted ? 0.42 : 0.26,
                    ),
                    kFinanzasOrangeIntense.withValues(
                      alpha: highlighted ? 0.34 : 0.18,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: highlighted
                      ? kFinanzasLightGlow.withValues(alpha: 0.70)
                      : kFinanzasBorder.withValues(alpha: 0.90),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: highlighted ? 32 : 22,
                    color: Colors.black.withValues(
                      alpha: highlighted ? 0.40 : 0.24,
                    ),
                    offset: Offset(0, highlighted ? 14 : 8),
                  ),
                  BoxShadow(
                    blurRadius: highlighted ? 30 : 18,
                    color: tokens.glow.withValues(
                      alpha: highlighted ? 0.36 : 0.20,
                    ),
                  ),
                ],
              ),
              child: widget.iconOnly
                  ? Center(
                      child: Icon(widget.icon, size: 22, color: Colors.white),
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
            ),
          ),
        ),
      ),
    );
  }
}

class FinanzasSummaryMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? accent;
  final Color? valueColor;
  final String? subtitle;
  final int subtitleMaxLines;
  final double? width;
  final double height;
  final bool centered;
  final double valueFontSize;
  final double labelFontSize;
  final double subtitleFontSize;
  final double iconBoxSize;
  final double iconSize;
  final EdgeInsetsGeometry padding;
  final double? progress;

  const FinanzasSummaryMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
    this.valueColor,
    this.subtitle,
    this.subtitleMaxLines = 3,
    this.width,
    this.height = 168,
    this.centered = false,
    this.valueFontSize = 24,
    this.labelFontSize = 12,
    this.subtitleFontSize = 12,
    this.iconBoxSize = 42,
    this.iconSize = 20,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final resolvedAccent = accent ?? tokens.primaryStrong;
    final resolvedValueColor = valueColor ?? kFinanzasOrange;
    final alignment = centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    final textAlign = centered ? TextAlign.center : TextAlign.start;
    return FinanzasGlassPanel(
      width: width,
      padding: padding,
      borderRadius: BorderRadius.circular(22),
      fillColor: kFinanzasPanelSurfaceStrong.withValues(alpha: 0.94),
      borderColor: resolvedAccent.withValues(alpha: 0.34),
      glowColor: resolvedAccent.withValues(alpha: 0.28),
      edgeHighlightColor: kFinanzasOrange.withValues(alpha: 0.14),
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: alignment,
          children: [
            Container(
              width: iconBoxSize,
              height: iconBoxSize,
              decoration: BoxDecoration(
                color: resolvedAccent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: resolvedAccent.withValues(alpha: 0.34),
                ),
              ),
              child: Icon(icon, color: resolvedAccent, size: iconSize),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              maxLines: 2,
              textAlign: textAlign,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: labelFontSize,
                fontWeight: FontWeight.w800,
                color: kFinanzasInk,
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: centered ? Alignment.center : Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                textAlign: textAlign,
                style: TextStyle(
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.w900,
                  color: resolvedValueColor,
                  height: 1,
                ),
              ),
            ),
            if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                subtitle!,
                maxLines: subtitleMaxLines,
                overflow: TextOverflow.ellipsis,
                textAlign: textAlign,
                style: TextStyle(
                  fontSize: subtitleFontSize,
                  fontWeight: FontWeight.w700,
                  color: kFinanzasMutedInk,
                  height: 1.3,
                ),
              ),
            ],
            if (progress != null) ...[
              const Spacer(),
              Container(
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: kFinanzasBgWarm.withValues(alpha: 0.88),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress!.clamp(0.0, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        colors: [
                          resolvedAccent.withValues(alpha: 0.58),
                          resolvedAccent.withValues(alpha: 0.92),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
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
    this.fillColor = kFinanzasPanelSurface,
    this.borderColor = kFinanzasBorder,
    this.shadowColor = const Color(0x8C000000),
    this.edgeHighlightColor = const Color(0x3DFF8A00),
    this.bevelShadowColor = const Color(0x3B160702),
    this.glowColor = kFinanzasGlowSoft,
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
                kFinanzasOrange.withValues(alpha: 0.10),
                kFinanzasOrangeElectric.withValues(alpha: 0.08),
                kFinanzasOrangeIntense.withValues(alpha: 0.10),
                Colors.transparent,
              ],
              stops: const [0.0, 0.16, 0.48, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 50,
                offset: const Offset(0, 18),
                color: shadowColor,
              ),
              BoxShadow(
                blurRadius: 32,
                spreadRadius: 1,
                offset: const Offset(0, 0),
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
                          kFinanzasOrangeElectric.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.16, 0.52],
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
                          kFinanzasOrangeElectric.withValues(alpha: 0.10),
                          kFinanzasOrange.withValues(alpha: 0.04),
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
                          color: edgeHighlightColor.withValues(alpha: 0.18),
                          blurRadius: 0,
                          spreadRadius: 0.6,
                        ),
                        BoxShadow(
                          color: bevelShadowColor.withValues(alpha: 0.18),
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
          fillColor: kFinanzasPanelSurfaceStrong.withValues(alpha: 0.82),
          borderColor: kFinanzasBorder.withValues(alpha: 0.92),
          shadowColor: Colors.black.withValues(alpha: 0.34),
          edgeHighlightColor: kFinanzasLightGlow.withValues(alpha: 0.18),
          bevelShadowColor: Colors.black.withValues(alpha: 0.20),
          glowColor: kFinanzasGlowStrong.withValues(alpha: 0.42),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: kFinanzasPearl,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xB8FFD5AB),
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
      fillColor: kFinanzasPanelSurfaceStrong.withValues(alpha: 0.68),
      borderColor: kFinanzasBorder.withValues(alpha: 0.80),
      shadowColor: Colors.black.withValues(alpha: 0.24),
      edgeHighlightColor: kFinanzasLightGlow.withValues(alpha: 0.14),
      bevelShadowColor: Colors.black.withValues(alpha: 0.18),
      glowColor: kFinanzasGlowSoft.withValues(alpha: 0.22),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: kFinanzasPearl),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: kFinanzasPearl,
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
    final current = widget.entry.current;
    final gradient = current
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kFinanzasOrange, kFinanzasOrangeIntense],
          )
        : null;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: widget.entry.current ? null : widget.entry.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            gradient: gradient,
            color: current
                ? null
                : highlighted
                ? kFinanzasSurfaceHover
                : kFinanzasPanelSurfaceStrong.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: current
                  ? kFinanzasBorderActive
                  : highlighted
                  ? kFinanzasBorderHover
                  : kFinanzasBorder.withValues(alpha: 0.72),
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: current ? 28 : 18,
                offset: const Offset(0, 10),
                color: Colors.black.withValues(alpha: current ? 0.28 : 0.18),
              ),
              BoxShadow(
                blurRadius: current ? 28 : 16,
                spreadRadius: current ? 1 : 0,
                color: (current ? kFinanzasGlowStrong : kFinanzasGlowSoft)
                    .withValues(alpha: current ? 0.52 : 0.20),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                widget.entry.icon,
                size: 18,
                color: current ? Colors.white : kFinanzasAmberHighlight,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.entry.title,
                      style: TextStyle(
                        color: current ? Colors.white : kFinanzasInk,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.entry.subtitle,
                      style: TextStyle(
                        color: current
                            ? Colors.white.withValues(alpha: 0.88)
                            : kFinanzasMutedInk,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.entry.current)
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20)
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: highlighted
                      ? kFinanzasAmberHighlight
                      : kFinanzasMutedInk,
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
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: kFinanzasHeroGradient),
          child: SizedBox.expand(),
        ),
        Positioned(
          left: -250,
          top: -140,
          child: _FinanzasBubbleCircle(
            size: 760,
            gradient: const LinearGradient(
              colors: [Color(0x66FF7A18), Color(0x14FF7A18)],
            ),
          ),
        ),
        Positioned(
          right: -180,
          top: -110,
          child: _FinanzasBubbleCircle(
            size: 620,
            gradient: const LinearGradient(
              colors: [Color(0x5CFF5A00), Color(0x18FF5A00)],
            ),
          ),
        ),
        Positioned(
          left: -160,
          bottom: -260,
          child: _FinanzasBubbleCircle(
            size: 620,
            gradient: const LinearGradient(
              colors: [Color(0x70FF8A00), Color(0x18FF8A00)],
            ),
          ),
        ),
        Positioned(
          right: -120,
          bottom: -120,
          child: IgnorePointer(
            child: _FinanzasBubblePill(
              width: 320,
              height: 520,
              radius: 220,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x7AFF8A00), Color(0x1AFF8A00)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FinanzasBubbleCircle extends StatelessWidget {
  final double size;
  final Gradient gradient;

  const _FinanzasBubbleCircle({required this.size, required this.gradient});

  @override
  Widget build(BuildContext context) {
    final lead = _finanzasGradientLead(gradient);
    final trail = _finanzasGradientTrail(gradient);
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
              color: lead.withValues(alpha: 0.17),
            ),
            BoxShadow(
              blurRadius: 78,
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
                      lead.withValues(alpha: 0.10),
                      trail.withValues(alpha: 0.18),
                      trail.withValues(alpha: 0.06),
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
}

class _FinanzasBubblePill extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final Gradient gradient;

  const _FinanzasBubblePill({
    required this.width,
    required this.height,
    required this.radius,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final lead = _finanzasGradientLead(gradient);
    final trail = _finanzasGradientTrail(gradient);
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
                    kFinanzasBgDeep.withValues(alpha: 0.10),
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
}

Color _finanzasGradientLead(Gradient gradient) {
  if (gradient is LinearGradient && gradient.colors.isNotEmpty) {
    return gradient.colors.first;
  }
  if (gradient is RadialGradient && gradient.colors.isNotEmpty) {
    return gradient.colors.first;
  }
  return kFinanzasAmber;
}

Color _finanzasGradientTrail(Gradient gradient) {
  if (gradient is LinearGradient && gradient.colors.isNotEmpty) {
    return gradient.colors.last;
  }
  if (gradient is RadialGradient && gradient.colors.isNotEmpty) {
    return gradient.colors.last;
  }
  return kFinanzasBurnt;
}
