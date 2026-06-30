import 'package:flutter/material.dart';

import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';

class HumanResourcesAreaNavEntry {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool accented;
  final Future<void> Function()? onTap;

  const HumanResourcesAreaNavEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accented = false,
    this.onTap,
  });
}

class HumanResourcesAreaBackground extends StatelessWidget {
  const HumanResourcesAreaBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF140B25), Color(0xFF24103F), Color(0xFF4A1D7A)],
            ),
          ),
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: -240,
          top: -140,
          child: _HumanResourcesBackgroundCircle(
            diameter: 760,
            colors: [Color(0xFF2A174A), Color(0xFF12091F)],
          ),
        ),
        Positioned(
          right: -180,
          top: -80,
          child: _HumanResourcesBackgroundCircle(
            diameter: 560,
            colors: [Color(0xFF9465F4), Color(0x33261540)],
          ),
        ),
        Positioned(
          left: 40,
          bottom: -240,
          child: _HumanResourcesBackgroundCircle(
            diameter: 660,
            colors: [Color(0x33573797), Color(0xFFE9D8FF)],
          ),
        ),
      ],
    );
  }
}

class _HumanResourcesBackgroundCircle extends StatelessWidget {
  final double diameter;
  final List<Color> colors;

  const _HumanResourcesBackgroundCircle({
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
              color: Colors.white.withValues(alpha: 0.03),
            ),
          ],
        ),
        child: SizedBox(width: diameter, height: diameter),
      ),
    );
  }
}

class HumanResourcesAreaHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;
  final bool compact;

  const HumanResourcesAreaHeaderButton({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
    this.compact = false,
  });

  @override
  State<HumanResourcesAreaHeaderButton> createState() =>
      _HumanResourcesAreaHeaderButtonState();
}

class _HumanResourcesAreaHeaderButtonState
    extends State<HumanResourcesAreaHeaderButton> {
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
              width: widget.compact ? 56 : 186,
              height: 56,
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 0 : 20,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: highlighted ? 0.18 : 0.12),
                    tokens.surfaceTint.withValues(
                      alpha: highlighted ? 0.20 : 0.12,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: highlighted
                      ? Colors.white.withValues(alpha: 0.30)
                      : Colors.white.withValues(alpha: 0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: highlighted ? 28 : 16,
                    color: Colors.black.withValues(
                      alpha: highlighted ? 0.22 : 0.12,
                    ),
                    offset: Offset(0, highlighted ? 14 : 8),
                  ),
                  BoxShadow(
                    blurRadius: highlighted ? 20 : 10,
                    color: tokens.glow.withValues(
                      alpha: highlighted ? 0.14 : 0.06,
                    ),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: widget.compact
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Icon(widget.icon, size: 20, color: tokens.onGlass),
                  if (!widget.compact) ...[
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
                            color: tokens.onGlass,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HumanResourcesAreaSidePanel extends StatelessWidget {
  final String label;
  final bool canReturnToDirection;
  final List<HumanResourcesAreaNavEntry> areaItems;
  final List<HumanResourcesAreaNavEntry> accessItems;

  const HumanResourcesAreaSidePanel({
    super.key,
    required this.label,
    required this.canReturnToDirection,
    required this.areaItems,
    required this.accessItems,
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
                label,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: tokens.onGlass,
                ),
              ),
              const SizedBox(height: 16),
              if (canReturnToDirection && accessItems.isNotEmpty) ...[
                HumanResourcesAreaNavItem(
                  icon: Icons.arrow_back_rounded,
                  title: 'Volver a Dirección',
                  subtitle: 'Regresar a la vista ejecutiva',
                  onTap: accessItems.first.onTap,
                ),
                const SizedBox(height: 10),
              ],
              const _HumanResourcesAreaSectionHeader(label: 'AREA'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x99432A65),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < areaItems.length; index++) ...[
                      HumanResourcesAreaNavItem(
                        icon: areaItems[index].icon,
                        title: areaItems[index].title,
                        subtitle: areaItems[index].subtitle,
                        accented: areaItems[index].accented,
                        onTap: areaItems[index].onTap,
                      ),
                      if (index != areaItems.length - 1)
                        const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _HumanResourcesAreaSectionHeader(label: 'ACCESOS'),
              const SizedBox(height: 8),
              for (var index = 0; index < accessItems.length; index++) ...[
                HumanResourcesAreaNavItem(
                  icon: accessItems[index].icon,
                  title: accessItems[index].title,
                  subtitle: accessItems[index].subtitle,
                  onTap: accessItems[index].onTap,
                ),
                if (index != accessItems.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HumanResourcesAreaSectionHeader extends StatelessWidget {
  final String label;

  const _HumanResourcesAreaSectionHeader({required this.label});

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
            color: tokens.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.10),
          ),
        ),
      ],
    );
  }
}

class HumanResourcesAreaNavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool accented;
  final Future<void> Function()? onTap;

  const HumanResourcesAreaNavItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accented = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accented
                  ? const Color(0xCC6B46C1)
                  : const Color(0x9925163A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: accented
                    ? Colors.white.withValues(alpha: 0.24)
                    : Colors.white.withValues(alpha: 0.08),
              ),
              boxShadow: accented
                  ? [
                      BoxShadow(
                        color: tokens.glow.withValues(alpha: 0.20),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: accented ? Colors.white : tokens.primary,
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
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(
                            alpha: accented ? 0.92 : 0.58,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!accented) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: tokens.primary,
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
