import 'dart:ui';

import 'package:flutter/material.dart';

import '../shared/dicsa_logo_mark.dart';
import '../shared/ui_contract_core/theme/contract_tokens.dart';

const ContractAreaTokens directionAreaTokens = ContractAreaTokens(
  primary: Color(0xFF7FD7FF),
  primaryStrong: Color(0xFFF4F8FF),
  primarySoft: Color(0xFFB7D8FF),
  accent: Color(0xFF52F0E4),
  surfaceTint: Color(0xFF081A39),
  border: Color(0xFF6EA7D6),
  badgeBackground: Color(0xFF183A73),
  badgeText: Color(0xFFD7E8FF),
  glow: Color(0xFF62D8FF),
);

const Color kDirectionSurfaceText = Color(0xFFF4F8FF);
const Color kDirectionMutedText = Color(0xFFB9CBE7);
const Color kDirectionSubtleText = Color(0xFF8EA9CF);

const LinearGradient kDirectionSelectionGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0x2AFFFFFF), Color(0x1E7FD7FF), Color(0x2816346C)],
  stops: [0.0, 0.48, 1.0],
);

class DirectionExecutiveBackground extends StatelessWidget {
  const DirectionExecutiveBackground({super.key});

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

class DirectionGlassPanel extends StatelessWidget {
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

  const DirectionGlassPanel({
    super.key,
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

class DirectionHeaderBrand extends StatelessWidget {
  final Animation<double> contentAnim;
  final String title;

  const DirectionHeaderBrand({
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
                  DirectionGlassPanel(
                    padding: EdgeInsets.zero,
                    borderRadius: BorderRadius.circular(22),
                    blurSigma: 24,
                    fillColor: const Color(0xFF8FD3FF).withValues(alpha: 0.08),
                    borderColor: Colors.white.withValues(alpha: 0.34),
                    shadowColor: const Color(
                      0xFF5EC8FF,
                    ).withValues(alpha: 0.08),
                    edgeHighlightColor: Colors.white.withValues(alpha: 0.72),
                    bevelShadowColor: Colors.black.withValues(alpha: 0.10),
                    glowColor: const Color(0xFF6BD5FF).withValues(alpha: 0.10),
                    child: const SizedBox(
                      width: 72,
                      height: 72,
                      child: Center(child: DicsaLogoD(size: 52, progress: 1.0)),
                    ),
                  ),
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

class DirectionHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;
  final double width;

  const DirectionHeaderButton({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
    this.width = 178,
  });

  @override
  State<DirectionHeaderButton> createState() => _DirectionHeaderButtonState();
}

class _DirectionHeaderButtonState extends State<DirectionHeaderButton> {
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
            child: DirectionGlassPanel(
              width: widget.width,
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

class DirectionMetricCard extends StatelessWidget {
  final double width;
  final double height;
  final IconData icon;
  final String title;
  final String value;
  final String detail;
  final Color accent;
  final EdgeInsetsGeometry margin;

  const DirectionMetricCard({
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
      child: DirectionGlassPanel(
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        borderRadius: BorderRadius.circular(16),
        blurSigma: 26,
        fillColor: const Color(0xFF173A78).withValues(alpha: 0.24),
        borderColor: Colors.white.withValues(alpha: 0.26),
        shadowColor: Colors.black.withValues(alpha: 0.08),
        edgeHighlightColor: Colors.white.withValues(alpha: 0.64),
        bevelShadowColor: Colors.black.withValues(alpha: 0.16),
        glowColor: accent.withValues(alpha: 0.10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withValues(alpha: 0.24)),
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
                      color: kDirectionSubtleText,
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
                      color: kDirectionSurfaceText,
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
                        color: kDirectionMutedText,
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

class DirectionToolbarPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const DirectionToolbarPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    return DirectionGlassPanel(
      padding: padding,
      borderRadius: BorderRadius.circular(20),
      blurSigma: 26,
      fillColor: const Color(0xFF173A78).withValues(alpha: 0.24),
      borderColor: Colors.white.withValues(alpha: 0.26),
      shadowColor: Colors.black.withValues(alpha: 0.08),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.62),
      bevelShadowColor: Colors.black.withValues(alpha: 0.16),
      glowColor: const Color(0xFF6DD7FF).withValues(alpha: 0.08),
      child: child,
    );
  }
}

class DirectionGridHeaderFilterCell extends StatelessWidget {
  final String label;
  final TextStyle style;
  final bool active;
  final Future<void> Function()? onTap;

  const DirectionGridHeaderFilterCell({
    super.key,
    required this.label,
    required this.style,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onTap != null) ...[
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onTap!.call(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF5EDCFF).withValues(alpha: 0.22)
                    : const Color(0xFF183A73).withValues(alpha: 0.74),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active
                      ? Colors.white.withValues(alpha: 0.42)
                      : Colors.white.withValues(alpha: 0.18),
                ),
              ),
              child: Icon(
                active ? Icons.filter_alt : Icons.filter_alt_outlined,
                size: 15,
                color: active ? Colors.white : kDirectionMutedText,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(label, style: style, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class DirectionGridPager extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final int totalRows;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<int> onPageSizeChanged;
  final ButtonStyle? secondaryButtonStyle;

  const DirectionGridPager({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.totalRows,
    required this.onPrevious,
    required this.onNext,
    required this.onPageSizeChanged,
    this.secondaryButtonStyle,
  });

  @override
  Widget build(BuildContext context) {
    final buttonStyle =
        secondaryButtonStyle ??
        OutlinedButton.styleFrom(
          foregroundColor: kDirectionSurfaceText,
          backgroundColor: const Color(0xFF16376F).withValues(alpha: 0.30),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        );
    return DirectionToolbarPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            style: buttonStyle,
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('Anterior'),
          ),
          Text(
            'Página ${currentPage + 1} de $totalPages',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: kDirectionSurfaceText,
            ),
          ),
          OutlinedButton.icon(
            style: buttonStyle,
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
            label: const Text('Siguiente'),
          ),
          const Text(
            'Filas/pág:',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: kDirectionMutedText,
            ),
          ),
          SizedBox(
            width: 92,
            child: DropdownButtonFormField<int>(
              initialValue: pageSize,
              isDense: true,
              dropdownColor: const Color(0xFF153160),
              iconEnabledColor: kDirectionSurfaceText,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: kDirectionSurfaceText,
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: const Color(0xFF10274E).withValues(alpha: 0.86),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: const Color(0xFF6FE1FF).withValues(alpha: 0.78),
                    width: 1.3,
                  ),
                ),
              ),
              items: const [40, 80, 120]
                  .map(
                    (size) => DropdownMenuItem<int>(
                      value: size,
                      child: Text('$size'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) onPageSizeChanged(value);
              },
            ),
          ),
          Text(
            'Total: $totalRows',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: kDirectionSurfaceText,
            ),
          ),
        ],
      ),
    );
  }
}
