import 'package:flutter/material.dart';
import '../shared/app_shell.dart';
import '../shared/dicsa_logo_mark.dart';

const double _kServicesTitleMinWidth = 500;

class ServicesShell extends StatelessWidget {
  final Widget child; // tu UI actual (la columna)
  final Future<void> Function()? onRefresh;
  final Future<void> Function()? onLogout;
  final Future<void> Function()? onGoToOperacion;
  final Future<void> Function()? onGoToCatalogs;

  const ServicesShell({
    super.key,
    required this.child,
    this.onRefresh,
    this.onLogout,
    this.onGoToOperacion,
    this.onGoToCatalogs,
  });

  @override
  Widget build(BuildContext context) {
    return AppShell(
      background: const _DicsaBackground(),
      leadingBuilder: (_, contentAnim) => AnimatedBuilder(
        animation: contentAnim,
        builder: (_, __) => Opacity(
          opacity: contentAnim.value,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HeaderActionButton(
                label: 'Dashboard',
                icon: Icons.dashboard,
                onTap: onGoToOperacion,
              ),
              const SizedBox(width: 8),
              _HeaderActionButton(
                label: 'Catálogos',
                icon: Icons.library_add,
                onTap: onGoToCatalogs,
              ),
            ],
          ),
        ),
      ),
      centerBuilder: (_, contentAnim) => _HeaderBrand(contentAnim: contentAnim),
      trailingBuilder: (_, contentAnim) => AnimatedBuilder(
        animation: contentAnim,
        builder: (_, __) => Opacity(
          opacity: contentAnim.value,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onRefresh != null) ...[
                _HeaderActionButton(
                  label: 'Recargar',
                  icon: Icons.refresh,
                  onTap: onRefresh,
                ),
                const SizedBox(width: 8),
              ],
              _HeaderActionButton(
                label: 'Cerrar sesión',
                icon: Icons.logout,
                onTap: onLogout,
              ),
            ],
          ),
        ),
      ),
      child: child,
    );
  }
}

class _HeaderBrand extends StatelessWidget {
  final Animation<double> contentAnim;
  const _HeaderBrand({required this.contentAnim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: contentAnim,
      builder: (_, __) => Opacity(
        opacity: contentAnim.value,
        child: Transform.translate(
          offset: Offset(0, (1 - contentAnim.value) * 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showTitle = constraints.maxWidth >= _kServicesTitleMinWidth;
              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.24),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.44),
                          ),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 24,
                              spreadRadius: 1,
                              color: const Color(0xFF0E86FF).withOpacity(0.20),
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: DicsaLogoD(size: 52, progress: 1.0),
                        ),
                      ),
                      if (showTitle) ...[
                        const SizedBox(width: 10),
                        Container(
                          width: 1.5,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B2B2B).withOpacity(0.28),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Flexible(
                          child: Text(
                            'Viajes y Servicios',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.25,
                              height: 1.0,
                              color: Color(0xFF0B2B2B),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;

  const _GlassIconButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<_GlassIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final highlighted = enabled && _hovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: highlighted ? 1.03 : 1.0,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          splashColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          onTap: enabled ? () => widget.onTap!() : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 158,
            height: 48,
            transform: Matrix4.translationValues(0, highlighted ? -2 : 0, 0),
            decoration: BoxDecoration(
              color: enabled
                  ? Colors.white.withOpacity(0.24)
                  : Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: enabled
                    ? Colors.white.withOpacity(0.64)
                    : Colors.white.withOpacity(0.32),
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: highlighted ? 30 : 18,
                  color: Colors.black.withOpacity(
                    enabled ? (highlighted ? 0.24 : 0.11) : 0.05,
                  ),
                  offset: Offset(0, highlighted ? 16 : 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 20, color: const Color(0xFF0B2B2B)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0B2B2B),
                    ),
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

class _HeaderActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;

  const _HeaderActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassIconButton(label: label, icon: icon, onTap: onTap);
  }
}

// Public reusable glass icon button (for other files)
class GlassIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Future<void> Function()? onTap;

  const GlassIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;

    final BoxDecoration enabledDeco = BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF19C37D), Color(0xFF00E0B0)],
      ),
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          blurRadius: 18,
          color: const Color(0xFF19C37D).withOpacity(0.28),
          offset: const Offset(0, 10),
        ),
      ],
    );

    final BoxDecoration disabledDeco = BoxDecoration(
      color: Colors.white.withOpacity(0.28),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withOpacity(0.35)),
      boxShadow: [
        BoxShadow(
          blurRadius: 18,
          color: Colors.black.withOpacity(0.06),
          offset: const Offset(0, 10),
        ),
      ],
    );

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      splashColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      onTap: enabled ? () => onTap!() : null,
      child: Container(
        width: 48,
        height: 48,
        decoration: enabled ? enabledDeco : disabledDeco,
        child: Icon(
          icon,
          size: 22,
          color: enabled ? Colors.white : const Color(0xFF0B2B2B),
        ),
      ),
    );
  }
}

class _DicsaBackground extends StatelessWidget {
  const _DicsaBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        /// BASE GRADIENT
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0B72FF), Color(0xFF21C9A6), Color(0xFF52F59A)],
            ),
          ),
        ),

        /// BIG GLASS ARC LEFT
        Positioned(
          left: -250,
          top: -120,
          child: _blurCircle(
            700,
            const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFF7ED0FF)],
            ),
          ),
        ),

        /// TOP RIGHT GLOW
        Positioned(
          right: -200,
          top: -80,
          child: _blurCircle(
            600,
            const LinearGradient(
              colors: [Color(0xFF4CFFB2), Color(0xFF00A3FF)],
            ),
          ),
        ),

        /// LOWER LEFT GLOW
        Positioned(
          left: -150,
          bottom: -250,
          child: _blurCircle(
            600,
            const LinearGradient(
              colors: [Color(0xFF0A84FF), Color(0xFF65FFE3)],
            ),
          ),
        ),

        /// RIGHT SIDE VERTICAL SHAPE
        Positioned(
          right: -120,
          bottom: -120,
          child: Container(
            width: 300,
            height: 500,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(200),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF00E0B0), Color(0xFF0080FF)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _blurCircle(double size, Gradient g) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: g),
    );
  }
}
