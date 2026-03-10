import 'dart:ui';

import 'package:flutter/material.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  final Widget background;
  final Widget Function(BuildContext context, Animation<double> contentAnim)?
  leadingBuilder;
  final Widget Function(BuildContext context, Animation<double> contentAnim)?
  centerBuilder;
  final Widget Function(BuildContext context, Animation<double> contentAnim)?
  trailingBuilder;
  final EdgeInsetsGeometry padding;
  final double headerBodySpacing;
  final bool wrapBodyInGlass;
  final Widget? bodyTop;
  final double bodyTopSpacing;
  final double headerCenterSidePadding;
  final double? minContentWidth;
  final bool animateHeaderSlots;
  final bool animateBody;
  final Widget? foregroundOverlay;

  const AppShell({
    super.key,
    required this.child,
    required this.background,
    this.leadingBuilder,
    this.centerBuilder,
    this.trailingBuilder,
    this.padding = const EdgeInsets.fromLTRB(18, 14, 18, 18),
    this.headerBodySpacing = 12,
    this.wrapBodyInGlass = true,
    this.bodyTop,
    this.bodyTopSpacing = 10,
    this.headerCenterSidePadding = 340,
    this.minContentWidth,
    this.animateHeaderSlots = true,
    this.animateBody = true,
    this.foregroundOverlay,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _content;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _content = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.55, 1.00, curve: Curves.easeOut),
    );
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _slot(Widget Function(BuildContext, Animation<double>)? builder) {
    if (builder == null) return const SizedBox.shrink();
    if (!widget.animateHeaderSlots) {
      return builder(context, const AlwaysStoppedAnimation<double>(1));
    }
    return AnimatedBuilder(
      animation: _content,
      builder: (context, _) =>
          Opacity(opacity: _content.value, child: builder(context, _content)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseShellContent = SafeArea(
      child: Padding(
        padding: widget.padding,
        child: Column(
          children: [
            SizedBox(
              height: 78,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _slot(widget.leadingBuilder),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.headerCenterSidePadding,
                    ),
                    child: Align(
                      alignment: Alignment.center,
                      child: _slot(widget.centerBuilder),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _slot(widget.trailingBuilder),
                  ),
                ],
              ),
            ),
            SizedBox(height: widget.headerBodySpacing),
            if (widget.bodyTop != null) ...[
              widget.animateBody
                  ? AnimatedBuilder(
                      animation: _content,
                      builder: (context, child) => Opacity(
                        opacity: _content.value,
                        child: Transform.translate(
                          offset: Offset(0, (1 - _content.value) * 10),
                          child: widget.bodyTop!,
                        ),
                      ),
                    )
                  : widget.bodyTop!,
              SizedBox(height: widget.bodyTopSpacing),
            ],
            Expanded(
              child: widget.animateBody
                  ? AnimatedBuilder(
                      animation: _content,
                      builder: (context, child) => Opacity(
                        opacity: _content.value,
                        child: Transform.translate(
                          offset: Offset(0, (1 - _content.value) * 14),
                          child: widget.wrapBodyInGlass
                              ? _GlassCard(child: widget.child)
                              : widget.child,
                        ),
                      ),
                    )
                  : (widget.wrapBodyInGlass
                        ? _GlassCard(child: widget.child)
                        : widget.child),
            ),
          ],
        ),
      ),
    );

    Widget shellContent = baseShellContent;
    if (widget.minContentWidth != null) {
      shellContent = LayoutBuilder(
        builder: (context, constraints) {
          final minWidth = widget.minContentWidth!;
          final contentWidth = constraints.maxWidth < minWidth
              ? minWidth
              : constraints.maxWidth;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: contentWidth,
              height: constraints.maxHeight,
              child: baseShellContent,
            ),
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          widget.background,
          shellContent,
          if (widget.foregroundOverlay != null) widget.foregroundOverlay!,
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
            boxShadow: [
              BoxShadow(
                blurRadius: 26,
                spreadRadius: 2,
                color: Colors.black.withValues(alpha: 0.06),
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
