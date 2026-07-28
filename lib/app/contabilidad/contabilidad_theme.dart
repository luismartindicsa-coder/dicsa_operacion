import 'dart:ui';

import 'package:flutter/material.dart';

import '../shared/ui_contract_core/theme/contract_tokens.dart';

const Color kContabilidadBg = Color(0xFF07161A);
const Color kContabilidadBgDeep = Color(0xFF031014);
const Color kContabilidadBgTeal = Color(0xFF0B2328);
const Color kContabilidadInk = Color(0xFFF2FCFC);
const Color kContabilidadMutedInk = Color(0xFFB7D3D6);
const Color kContabilidadSubtleInk = Color(0xFF7FA6AB);
const Color kContabilidadLine = Color(0x3E82D5DB);
const Color kContabilidadGlow = Color(0xFF67D2D8);
const Color kContabilidadMint = Color(0xFF87E6BF);
const Color kContabilidadSurface = Color(0xB2162D31);
const Color kContabilidadSurfaceStrong = Color(0xCC11363C);
const Color kContabilidadSurfaceSoft = Color(0xA6112529);
const Color kContabilidadSuccess = Color(0xFF8AE0A2);

const ContractAreaTokens contabilidadAreaTokens = ContractAreaTokens(
  primary: kContabilidadGlow,
  primaryStrong: Color(0xFF39B8C1),
  primarySoft: Color(0xFFA8EEF1),
  accent: kContabilidadMint,
  surfaceTint: Color(0xFF11353A),
  border: kContabilidadLine,
  badgeBackground: Color(0x302A676D),
  badgeText: Color(0xFFBFF7EA),
  glow: kContabilidadGlow,
  darkGlass: true,
  accentDarkGlass: true,
  glassSurface: kContabilidadSurface,
  fieldSurface: Color(0xC2142A2F),
  onGlass: kContabilidadInk,
);

const LinearGradient kContabilidadSelectionGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0x22FFFFFF), Color(0x2867D2D8), Color(0x2687E6BF)],
  stops: [0.0, 0.46, 1.0],
);

class ContabilidadAreaBackground extends StatelessWidget {
  const ContabilidadAreaBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                kContabilidadBg,
                kContabilidadBgDeep,
                kContabilidadBgTeal,
              ],
            ),
          ),
          child: SizedBox.expand(),
        ),
        Positioned(
          left: -220,
          top: -110,
          child: _ContabilidadBackgroundCircle(
            diameter: 660,
            colors: [Color(0xFF18474F), Color(0xFF07161A)],
          ),
        ),
        Positioned(
          right: -190,
          top: -70,
          child: _ContabilidadBackgroundCircle(
            diameter: 580,
            colors: [Color(0x9967D2D8), Color(0x11143639)],
          ),
        ),
        Positioned(
          left: 40,
          bottom: -220,
          child: _ContabilidadBackgroundCircle(
            diameter: 560,
            colors: [Color(0x3387E6BF), Color(0x11F2FCFC)],
          ),
        ),
      ],
    );
  }
}

class ContabilidadGlassPanel extends StatelessWidget {
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

  const ContabilidadGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    required this.borderRadius,
    this.blurSigma = 24,
    required this.fillColor,
    required this.borderColor,
    required this.shadowColor,
    required this.edgeHighlightColor,
    required this.bevelShadowColor,
    required this.glowColor,
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
          padding: padding,
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: borderRadius,
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
              BoxShadow(color: glowColor, blurRadius: 24, spreadRadius: 0.5),
            ],
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(color: edgeHighlightColor, width: 0.7),
            boxShadow: [
              BoxShadow(
                color: bevelShadowColor,
                blurRadius: 10,
                spreadRadius: -6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class ContabilidadPageHeaderBrand extends StatelessWidget {
  final Animation<double> contentAnim;
  final String title;

  const ContabilidadPageHeaderBrand({
    super.key,
    required this.contentAnim,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: contentAnim,
      builder: (context, child) => Opacity(
        opacity: contentAnim.value,
        child: Transform.translate(
          offset: Offset(0, (1 - contentAnim.value) * 10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: IntrinsicHeight(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ContabilidadGlassPanel(
                    padding: EdgeInsets.zero,
                    borderRadius: BorderRadius.circular(22),
                    blurSigma: 24,
                    fillColor: kContabilidadSurfaceStrong,
                    borderColor: Colors.white.withValues(alpha: 0.22),
                    shadowColor: Colors.black.withValues(alpha: 0.16),
                    edgeHighlightColor: Colors.white.withValues(alpha: 0.62),
                    bevelShadowColor: Colors.black.withValues(alpha: 0.10),
                    glowColor: kContabilidadGlow.withValues(alpha: 0.14),
                    child: const SizedBox(
                      width: 72,
                      height: 72,
                      child: Center(
                        child: Icon(
                          Icons.account_balance_rounded,
                          size: 38,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.25,
                        height: 1.0,
                        color: Colors.white,
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

class ContabilidadPageHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;
  final double width;

  const ContabilidadPageHeaderButton({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
    this.width = 178,
  });

  @override
  State<ContabilidadPageHeaderButton> createState() =>
      _ContabilidadPageHeaderButtonState();
}

class _ContabilidadPageHeaderButtonState
    extends State<ContabilidadPageHeaderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onTapSync != null;
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
            onTap: enabled
                ? () async {
                    if (widget.onTap != null) {
                      await widget.onTap!();
                    } else {
                      widget.onTapSync?.call();
                    }
                  }
                : null,
            child: ContabilidadGlassPanel(
              width: widget.width,
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              borderRadius: BorderRadius.circular(16),
              blurSigma: 26,
              fillColor: enabled
                  ? kContabilidadSurfaceStrong.withValues(
                      alpha: highlighted ? 0.88 : 0.72,
                    )
                  : Colors.white.withValues(alpha: 0.05),
              borderColor: enabled
                  ? Colors.white.withValues(alpha: highlighted ? 0.42 : 0.24)
                  : Colors.white.withValues(alpha: 0.16),
              shadowColor: highlighted
                  ? Colors.black.withValues(alpha: 0.16)
                  : Colors.black.withValues(alpha: 0.08),
              edgeHighlightColor: Colors.white.withValues(alpha: 0.64),
              bevelShadowColor: Colors.black.withValues(alpha: 0.12),
              glowColor: highlighted
                  ? kContabilidadGlow.withValues(alpha: 0.24)
                  : kContabilidadMint.withValues(alpha: 0.12),
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

class ContabilidadMetricCard extends StatelessWidget {
  final double width;
  final double height;
  final IconData icon;
  final String title;
  final String value;
  final String detail;
  final Color accent;
  final EdgeInsetsGeometry margin;

  const ContabilidadMetricCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    required this.accent,
    this.width = 310,
    this.height = 72,
    this.margin = const EdgeInsets.only(right: 6),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: ContabilidadGlassPanel(
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        borderRadius: BorderRadius.circular(16),
        blurSigma: 26,
        fillColor: kContabilidadSurfaceStrong.withValues(alpha: 0.74),
        borderColor: Colors.white.withValues(alpha: 0.20),
        shadowColor: Colors.black.withValues(alpha: 0.08),
        edgeHighlightColor: Colors.white.withValues(alpha: 0.58),
        bevelShadowColor: Colors.black.withValues(alpha: 0.16),
        glowColor: accent.withValues(alpha: 0.12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withValues(alpha: 0.26)),
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: kContabilidadSubtleInk,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: kContabilidadInk,
                      height: 1.0,
                    ),
                  ),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: kContabilidadMutedInk,
                        height: 1.0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ContabilidadToolbarPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const ContabilidadToolbarPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    return ContabilidadGlassPanel(
      padding: padding,
      borderRadius: BorderRadius.circular(20),
      blurSigma: 26,
      fillColor: kContabilidadSurfaceStrong.withValues(alpha: 0.74),
      borderColor: Colors.white.withValues(alpha: 0.20),
      shadowColor: Colors.black.withValues(alpha: 0.08),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.58),
      bevelShadowColor: Colors.black.withValues(alpha: 0.16),
      glowColor: kContabilidadGlow.withValues(alpha: 0.10),
      child: child,
    );
  }
}

class _ContabilidadBackgroundCircle extends StatelessWidget {
  final double diameter;
  final List<Color> colors;

  const _ContabilidadBackgroundCircle({
    required this.diameter,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: colors),
          boxShadow: [
            BoxShadow(
              blurRadius: diameter * 0.10,
              spreadRadius: diameter * 0.015,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ],
        ),
        child: SizedBox(width: diameter, height: diameter),
      ),
    );
  }
}
