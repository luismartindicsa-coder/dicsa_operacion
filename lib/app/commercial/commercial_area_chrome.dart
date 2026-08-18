import 'package:flutter/material.dart';

import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import 'commercial_theme.dart';

class CommercialAreaNavEntry {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool accented;
  final Future<void> Function()? onTap;

  const CommercialAreaNavEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accented = false,
    this.onTap,
  });
}

class CommercialAreaBackground extends StatelessWidget {
  const CommercialAreaBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF060807), Color(0xFF111613), Color(0xFF202B25)],
            ),
          ),
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: -220,
          top: -120,
          child: _CommercialBackgroundCircle(
            diameter: 720,
            colors: [Color(0xFF29352D), Color(0xFF0A0F0C)],
          ),
        ),
        Positioned(
          right: -170,
          top: -70,
          child: _CommercialBackgroundCircle(
            diameter: 560,
            colors: [Color(0xFF53695D), Color(0x3318211C)],
          ),
        ),
        Positioned(
          left: 40,
          bottom: -230,
          child: _CommercialBackgroundCircle(
            diameter: 620,
            colors: [Color(0x334B5E53), Color(0xFFE2B14F)],
          ),
        ),
      ],
    );
  }
}

class _CommercialBackgroundCircle extends StatelessWidget {
  final double diameter;
  final List<Color> colors;

  const _CommercialBackgroundCircle({
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

class CommercialAreaHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;
  final bool compact;

  const CommercialAreaHeaderButton({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
    this.compact = false,
  });

  @override
  State<CommercialAreaHeaderButton> createState() =>
      _CommercialAreaHeaderButtonState();
}

class _CommercialAreaHeaderButtonState
    extends State<CommercialAreaHeaderButton> {
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
                    Colors.white.withValues(alpha: highlighted ? 0.18 : 0.10),
                    tokens.surfaceTint.withValues(
                      alpha: highlighted ? 0.22 : 0.14,
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
                      alpha: highlighted ? 0.14 : 0.05,
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
                            fontWeight: FontWeight.w900,
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

class CommercialAreaDialogShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback onSave;
  final String saveLabel;

  const CommercialAreaDialogShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onSave,
    this.saveLabel = 'Guardar',
  });

  @override
  Widget build(BuildContext context) {
    final areaTheme = buildCommercialAreaTheme(Theme.of(context));
    return Theme(
      data: areaTheme.copyWith(
        textTheme: areaTheme.textTheme.apply(
          bodyColor: kCommercialInk,
          displayColor: kCommercialInk,
          decorationColor: kCommercialInk,
        ),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: kCommercialInk),
        child: IconTheme(
          data: const IconThemeData(color: kCommercialInk),
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
                decoration: BoxDecoration(
                  color: const Color(0xF018211D),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x5A000000),
                      blurRadius: 54,
                      offset: Offset(0, 20),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: kCommercialInk,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  subtitle,
                                  style: const TextStyle(
                                    color: Color(0xD9F3F1E8),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      child,
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(color: Color(0xD9F3F1E8)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF183826),
                              foregroundColor: const Color(0xFFF3F1E8),
                              side: const BorderSide(color: Color(0xFF2D6E49)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            onPressed: onSave,
                            icon: const Icon(
                              Icons.save_rounded,
                              color: Color(0xFF41D978),
                            ),
                            label: Text(saveLabel),
                          ),
                        ],
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
  }
}

class CommercialAreaSidePanel extends StatelessWidget {
  final String label;
  final bool canReturnToDirection;
  final List<CommercialAreaNavEntry> areaItems;
  final List<CommercialAreaNavEntry> accessItems;

  const CommercialAreaSidePanel({
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
                CommercialAreaNavItem(
                  icon: Icons.arrow_back_rounded,
                  title: 'Volver a Dirección',
                  subtitle: 'Regresar a la vista ejecutiva',
                  onTap: accessItems.first.onTap,
                ),
                const SizedBox(height: 10),
              ],
              const CommercialAreaSectionHeader(label: 'AREA'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.glassSurface.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < areaItems.length; index++) ...[
                      CommercialAreaNavItem(
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
              const CommercialAreaSectionHeader(label: 'ACCESOS'),
              const SizedBox(height: 8),
              for (var index = 0; index < accessItems.length; index++) ...[
                CommercialAreaNavItem(
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

class CommercialAreaSectionHeader extends StatelessWidget {
  final String label;

  const CommercialAreaSectionHeader({super.key, required this.label});

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

class CommercialAreaNavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool accented;
  final Future<void> Function()? onTap;

  const CommercialAreaNavItem({
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
              gradient: accented
                  ? kCommercialHeroGradient
                  : kCommercialPanelGradient,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: accented
                    ? Colors.white.withValues(alpha: 0.72)
                    : Colors.white.withValues(alpha: 0.58),
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
                  color: accented ? Colors.white : tokens.onGlass,
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
                          color: accented ? Colors.white : tokens.onGlass,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accented
                              ? Colors.white.withValues(alpha: 0.92)
                              : tokens.badgeText,
                        ),
                      ),
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
