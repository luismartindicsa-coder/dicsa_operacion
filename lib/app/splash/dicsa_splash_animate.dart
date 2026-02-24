import 'dart:math';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

import '../auth/auth_gate.dart';
import '../shared/dicsa_logo_mark.dart';

class DicsaSplashAnimate extends StatefulWidget {
  const DicsaSplashAnimate({super.key});

  @override
  State<DicsaSplashAnimate> createState() => _DicsaSplashAnimateState();
}

class _DicsaSplashAnimateState extends State<DicsaSplashAnimate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _navigated = false;

  // Ajustes layout/anim
  static const double kLogoScale = 0.40;
  static const double kMoveUp = 0.05;
  static const double kGapVertical = 0.04;

  static const double kWordScale = 0.40;
  static const double kPenFracD = 0.10;
  static const double kPenFracW = 0.08;

  static const double kWordWidthFactor = 1.30;
  static const double kStartScale = 1.10;

  double _map(double t, double a, double b) {
    if (t <= a) return 0;
    if (t >= b) return 1;
    return (t - a) / (b - a);
  }

  @override
  void initState() {
    super.initState();

    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_navigated) {
        _navigated = true;

        Future.delayed(const Duration(milliseconds: 120), () {
          if (!mounted) return;

          // ✅ Sin slide. Fade suave + Hero hace el “abrirse”.
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 900),
              reverseTransitionDuration: const Duration(milliseconds: 700),
              pageBuilder: (_, _, _) => const AuthGate(),
              transitionsBuilder: (_, animation, _, child) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOutCubic,
                );
                return FadeTransition(opacity: curved, child: child);
              },
            ),
          );
        });
      }
    });

    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final t = _c.value;

          // 1) D se dibuja + rellena
          final dT = Curves.easeInOut.transform(_map(t, 0.00, 0.68));

          // 2) movimiento final (sube D y entra wordmark)
          final moveT = Curves.easeInOut.transform(_map(t, 0.68, 0.88));

          // 3) word se “escribe”
          final wT = Curves.easeInOut.transform(_map(t, 0.72, 1.00));

          return Stack(
            children: [
              const _SplashBackground(),
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (_, cts) => _SplashBubblesLayer(
                    t: t,
                    screenW: cts.maxWidth,
                    screenH: cts.maxHeight,
                  ),
                ),
              ),
              LayoutBuilder(
                builder: (_, cts) {
                  final w = cts.maxWidth;
                  final h = cts.maxHeight;

                  final dSize = min(w, h) * kLogoScale;
                  final wordH = dSize * kWordScale;
                  final wordW = dSize * kWordWidthFactor;

                  final gapY = dSize * kGapVertical;
                  final totalH = dSize + gapY + wordH;
                  final totalW = max(dSize, wordW);

                  final dX = (totalW - dSize) / 2;

                  final wordXEnd = (totalW - wordW) / 2;
                  final wordXStart = -wordW; // entra desde izquierda
                  final wordX = lerpDouble(wordXStart, wordXEnd, moveT)!;

                  final wordY = dSize + gapY;

                  final dY = lerpDouble(0.0, -dSize * kMoveUp, moveT)!;
                  final scale = lerpDouble(kStartScale, 1.0, moveT)!;

                  return Center(
                    child: Transform.scale(
                      scale: scale,
                      child: SizedBox(
                        width: totalW,
                        height: totalH,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            if (moveT > 0.0001)
                              Positioned(
                                left: wordX,
                                top: wordY,
                                child: DicsaWordMark(
                                  width: wordW,
                                  height: wordH,
                                  progress: wT,
                                  penFrac: kPenFracW,
                                ),
                              ),
                            Positioned(
                              left: dX,
                              top: dY,
                              child: Hero(
                                tag: 'dicsa_d',
                                child: DicsaLogoD(
                                  size: dSize,
                                  progress: dT,
                                  penFrac: kPenFracD,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SplashBackground extends StatelessWidget {
  const _SplashBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0B72FF), Color(0xFF21C9A6), Color(0xFF52F59A)],
            ),
          ),
        ),
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

class _SplashBubblesLayer extends StatelessWidget {
  final double t;
  final double screenW;
  final double screenH;

  const _SplashBubblesLayer({
    required this.t,
    required this.screenW,
    required this.screenH,
  });

  static const List<_BubbleSpec> _specs = [
    _BubbleSpec(
      sizeFactor: 0.80,
      anchorX: 0.08,
      anchorY: 0.16,
      phase: 0.2,
      speed: 0.18,
      alpha: 0.30,
      wobbleX: 0.05,
      wobbleY: 0.18,
      color: Color(0xFFECFEFF),
    ),
    _BubbleSpec(
      sizeFactor: 0.76,
      anchorX: 0.90,
      anchorY: 0.14,
      phase: 1.1,
      speed: 0.22,
      alpha: 0.24,
      wobbleX: 0.06,
      wobbleY: 0.16,
      color: Color(0xFFD6FFF2),
    ),
    _BubbleSpec(
      sizeFactor: 0.86,
      anchorX: 0.52,
      anchorY: 0.46,
      phase: 2.3,
      speed: 0.19,
      alpha: 0.20,
      wobbleX: 0.05,
      wobbleY: 0.19,
      color: Color(0xFFDDFEFF),
    ),
    _BubbleSpec(
      sizeFactor: 0.94,
      anchorX: 0.14,
      anchorY: 0.86,
      phase: 3.4,
      speed: 0.16,
      alpha: 0.28,
      wobbleX: 0.04,
      wobbleY: 0.15,
      color: Color(0xFFFFFFFF),
    ),
    _BubbleSpec(
      sizeFactor: 0.70,
      anchorX: 0.86,
      anchorY: 0.84,
      phase: 4.2,
      speed: 0.21,
      alpha: 0.23,
      wobbleX: 0.05,
      wobbleY: 0.14,
      color: Color(0xFFCCFFF7),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final base = min(screenW, screenH);
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: _specs.map((spec) {
          final fadeOut = (1.0 - ((t - 0.80) / 0.20)).clamp(0.0, 1.0);
          final bubbleSize = base * spec.sizeFactor;
          final baseX = screenW * spec.anchorX;
          final baseY = screenH * spec.anchorY;

          final dx =
              (sin((t * pi * 2 * spec.speed) + spec.phase) *
                  base *
                  spec.wobbleX) +
              (cos((t * pi * 2 * spec.speed * 0.65) + spec.phase * 0.8) *
                  base *
                  (spec.wobbleX * 0.75));
          final dy =
              (cos((t * pi * 2 * spec.speed * 0.85) + spec.phase * 1.1) *
                  base *
                  spec.wobbleY) +
              (sin((t * pi * 2 * spec.speed * 0.55) + spec.phase * 0.6) *
                  base *
                  (spec.wobbleY * 0.60));

          return Positioned(
            left: baseX + dx - bubbleSize * 0.5,
            top: baseY + dy - bubbleSize * 0.5,
            child: Container(
              width: bubbleSize,
              height: bubbleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: spec.color.withValues(alpha: spec.alpha * fadeOut),
                boxShadow: [
                  BoxShadow(
                    color: spec.color.withValues(
                      alpha: spec.alpha * 0.78 * fadeOut,
                    ),
                    blurRadius: bubbleSize * 0.20,
                    spreadRadius: bubbleSize * 0.02,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BubbleSpec {
  final double sizeFactor;
  final double anchorX;
  final double anchorY;
  final double phase;
  final double speed;
  final double alpha;
  final double wobbleX;
  final double wobbleY;
  final Color color;

  const _BubbleSpec({
    required this.sizeFactor,
    required this.anchorX,
    required this.anchorY,
    required this.phase,
    required this.speed,
    required this.alpha,
    required this.wobbleX,
    required this.wobbleY,
    required this.color,
  });
}
