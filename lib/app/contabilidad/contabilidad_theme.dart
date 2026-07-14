import 'dart:ui';

import 'package:flutter/material.dart';

import '../shared/dicsa_logo_mark.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_tokens.dart';

const Color kContabilidadBg = Color(0xFF07161A);
const Color kContabilidadBgDeep = Color(0xFF031014);
const Color kContabilidadBgTeal = Color(0xFF0B2328);
const Color kContabilidadInk = Color(0xFFF2FCFC);
const Color kContabilidadMutedInk = Color(0xFFB7D3D6);
const Color kContabilidadLine = Color(0x3E82D5DB);
const Color kContabilidadGlow = Color(0xFF67D2D8);
const Color kContabilidadMint = Color(0xFF87E6BF);
const Color kContabilidadSurface = Color(0xB2162D31);
const Color kContabilidadSurfaceStrong = Color(0xCC11363C);
const Color kContabilidadSurfaceSoft = Color(0xA6112529);

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

class ContabilidadAreaBackground extends StatelessWidget {
  const ContabilidadAreaBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kContabilidadBg, kContabilidadBgDeep, kContabilidadBgTeal],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: -140,
            top: -120,
            child: _GlowOrb(
              size: 360,
              color: kContabilidadGlow.withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            right: -80,
            top: 140,
            child: _GlowOrb(
              size: 280,
              color: kContabilidadMint.withValues(alpha: 0.14),
            ),
          ),
          Positioned(
            left: 180,
            bottom: -120,
            child: _GlowOrb(
              size: 340,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
        ],
      ),
    );
  }
}

class ContabilidadPageHeaderBrand extends StatelessWidget {
  final String title;

  const ContabilidadPageHeaderBrand({super.key, required this.title});

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
            color: kContabilidadSurfaceStrong,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kContabilidadLine),
            boxShadow: [
              BoxShadow(
                color: tokens.glow.withValues(alpha: 0.26),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Center(child: DicsaLogoD(size: 40, progress: 1)),
        ),
        const SizedBox(width: 18),
        Text(
          title,
          style: const TextStyle(
            color: kContabilidadInk,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class ContabilidadPageHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;
  final bool iconOnly;

  const ContabilidadPageHeaderButton({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
    this.iconOnly = false,
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
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              kContabilidadGlow.withValues(alpha: _hovered ? 0.28 : 0.18),
              kContabilidadMint.withValues(alpha: _hovered ? 0.22 : 0.12),
            ],
          ),
          border: Border.all(
            color: _hovered
                ? kContabilidadGlow.withValues(alpha: 0.70)
                : kContabilidadLine,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: !enabled
                ? null
                : () async {
                    if (widget.onTap != null) {
                      await widget.onTap!();
                    } else {
                      widget.onTapSync?.call();
                    }
                  },
            child: SizedBox(
              width: widget.iconOnly ? 56 : 188,
              height: 56,
              child: widget.iconOnly
                  ? Icon(widget.icon, color: Colors.white)
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        children: [
                          Icon(widget.icon, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
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

class ContabilidadSidePanelItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool current;
  final Future<void> Function()? onTap;

  const ContabilidadSidePanelItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.current = false,
    this.onTap,
  });
}

class ContabilidadAreaSidePanel extends StatelessWidget {
  final List<ContabilidadSidePanelItem> items;

  const ContabilidadAreaSidePanel({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: kContabilidadSurfaceSoft,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Contabilidad',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Lectura consolidada, sin captura manual.',
                style: TextStyle(
                  color: kContabilidadMutedInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              for (final item in items) ...[
                _ContabilidadNavTile(item: item),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ContabilidadPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const ContabilidadPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: kContabilidadSurface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ContabilidadNavTile extends StatefulWidget {
  final ContabilidadSidePanelItem item;

  const _ContabilidadNavTile({required this.item});

  @override
  State<_ContabilidadNavTile> createState() => _ContabilidadNavTileState();
}

class _ContabilidadNavTileState extends State<_ContabilidadNavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return MouseRegion(
      cursor: item.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: item.onTap == null ? null : () async => item.onTap!(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: item.current
                  ? kContabilidadGlow.withValues(alpha: 0.16)
                  : (_hovered
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.transparent),
              border: Border.all(
                color: item.current
                    ? kContabilidadGlow.withValues(alpha: 0.42)
                    : Colors.white.withValues(alpha: 0.10),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  child: Icon(item.icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        style: const TextStyle(
                          color: kContabilidadMutedInk,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
