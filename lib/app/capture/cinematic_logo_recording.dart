import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../shared/dicsa_logo_mark.dart';

void main() {
  runApp(const _CinematicLogoRecordingApp());
}

class _CinematicLogoRecordingApp extends StatelessWidget {
  const _CinematicLogoRecordingApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CinematicLogoRecordingScreen(),
    );
  }
}

class CinematicLogoRecordingScreen extends StatefulWidget {
  const CinematicLogoRecordingScreen({super.key});

  @override
  State<CinematicLogoRecordingScreen> createState() =>
      _CinematicLogoRecordingScreenState();
}

class _CinematicLogoRecordingScreenState
    extends State<CinematicLogoRecordingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  static const double _kLogoScale = 0.40;
  static const double _kMoveUp = 0.05;
  static const double _kGapVertical = 0.04;
  static const double _kWordScale = 0.40;
  static const double _kPenFracD = 0.10;
  static const double _kPenFracW = 0.08;
  static const double _kWordWidthFactor = 1.30;
  static const double _kStartScale = 1.10;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16000),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _map(double t, double a, double b) {
    if (t <= a) return 0;
    if (t >= b) return 1;
    return (t - a) / (b - a);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final t = _c.value;
          final revealT = Curves.easeInOutCubicEmphasized.transform(
            _map(t, 0.00, 0.30),
          );
          final bgFadeT = Curves.easeOutCubic.transform(_map(t, 0.03, 0.34));
          final dT = Curves.easeInOut.transform(_map(t, 0.24, 0.40));
          final moveT = Curves.easeInOut.transform(_map(t, 0.37, 0.50));
          final wT = Curves.easeInOut.transform(_map(t, 0.40, 0.53));
          final toWelcomeT = Curves.easeInOutCubic.transform(
            _map(t, 0.61, 0.78),
          );
          final wordDropT = Curves.easeInOutCubic.transform(
            _map(t, 0.63, 0.78),
          );
          final welcomeT = Curves.easeOutCubic.transform(_map(t, 0.67, 0.83));

          return Stack(
            children: [
              Opacity(
                opacity: bgFadeT,
                child: LayoutBuilder(
                  builder: (_, cts) => _CinematicBackdrop(
                    t: t,
                    screenW: cts.maxWidth,
                    screenH: cts.maxHeight,
                  ),
                ),
              ),
              if (revealT < 1.0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _IrisRevealOverlayPainter(progress: revealT),
                    ),
                  ),
                ),
              LayoutBuilder(
                builder: (_, cts) {
                  final w = cts.maxWidth;
                  final h = cts.maxHeight;

                  final dSize = min(w, h) * _kLogoScale;
                  final wordH = dSize * _kWordScale;
                  final wordW = dSize * _kWordWidthFactor;
                  final gapY = dSize * _kGapVertical;
                  final extraCopySpace = dSize * 0.34;
                  final totalH = dSize + gapY + wordH + extraCopySpace;
                  final totalW = max(dSize, wordW);
                  final dX = (totalW - dSize) / 2;

                  final wordXEnd = (totalW - wordW) / 2;
                  final wordXStart = -wordW;
                  final wordX = lerpDouble(wordXStart, wordXEnd, moveT)!;
                  final baseWordY = dSize + gapY;
                  final wordY =
                      baseWordY + lerpDouble(0.0, dSize * 0.28, wordDropT)!;
                  final copyY = baseWordY + dSize * 0.035;

                  final dY = lerpDouble(0.0, -dSize * _kMoveUp, moveT)!;
                  final introScale = lerpDouble(_kStartScale, 1.0, moveT)!;
                  final finalScale = lerpDouble(1.0, 0.66, toWelcomeT)!;

                  return Stack(
                    children: [
                      Align(
                        alignment: Alignment.lerp(
                          Alignment.center,
                          const Alignment(0, -0.36),
                          toWelcomeT,
                        )!,
                        child: Transform.scale(
                          scale: introScale * finalScale,
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
                                      penFrac: _kPenFracW,
                                    ),
                                  ),
                                Positioned(
                                  left: dX,
                                  top: dY,
                                  child: DicsaLogoD(
                                    size: dSize,
                                    progress: dT,
                                    penFrac: _kPenFracD,
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: copyY,
                                  child: Opacity(
                                    opacity: welcomeT,
                                    child: Transform.translate(
                                      offset: Offset(
                                        0,
                                        lerpDouble(14, 0, welcomeT)!,
                                      ),
                                      child: Text(
                                        'BIENVENIDOS AL NUEVO',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: DicsaSvgPaths.word,
                                          fontSize: 36,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.1,
                                          height: 1.0,
                                          shadows: [
                                            Shadow(
                                              color: Colors.white.withValues(
                                                alpha: 0.30,
                                              ),
                                              blurRadius: 16,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _CinematicBackdrop extends StatelessWidget {
  const _CinematicBackdrop({
    required this.t,
    required this.screenW,
    required this.screenH,
  });

  final double t;
  final double screenW;
  final double screenH;

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
        Positioned.fill(
          child: _CinematicBubblesLayer(
            t: t,
            screenW: screenW,
            screenH: screenH,
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.08),
                  radius: 1.05,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.14),
                    Colors.black.withValues(alpha: 0.34),
                  ],
                  stops: const [0.56, 0.84, 1.0],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _blurCircle(double size, Gradient gradient) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
    );
  }
}

class _CinematicBubblesLayer extends StatelessWidget {
  const _CinematicBubblesLayer({
    required this.t,
    required this.screenW,
    required this.screenH,
  });

  final double t;
  final double screenW;
  final double screenH;

  static const List<_BubbleSpec> _specs = [
    _BubbleSpec(
      sizeFactor: 0.80,
      anchorX: 0.08,
      anchorY: 0.16,
      phase: 0.2,
      speed: 2,
      alpha: 0.26,
      wobbleX: 0.04,
      wobbleY: 0.14,
      color: Color(0xFFECFEFF),
    ),
    _BubbleSpec(
      sizeFactor: 0.76,
      anchorX: 0.90,
      anchorY: 0.14,
      phase: 1.1,
      speed: 3,
      alpha: 0.22,
      wobbleX: 0.05,
      wobbleY: 0.13,
      color: Color(0xFFD6FFF2),
    ),
    _BubbleSpec(
      sizeFactor: 0.86,
      anchorX: 0.52,
      anchorY: 0.46,
      phase: 2.3,
      speed: 2,
      alpha: 0.18,
      wobbleX: 0.04,
      wobbleY: 0.16,
      color: Color(0xFFDDFEFF),
    ),
    _BubbleSpec(
      sizeFactor: 0.94,
      anchorX: 0.14,
      anchorY: 0.86,
      phase: 3.4,
      speed: 1,
      alpha: 0.24,
      wobbleX: 0.04,
      wobbleY: 0.12,
      color: Color(0xFFFFFFFF),
    ),
    _BubbleSpec(
      sizeFactor: 0.70,
      anchorX: 0.86,
      anchorY: 0.84,
      phase: 4.2,
      speed: 2,
      alpha: 0.21,
      wobbleX: 0.05,
      wobbleY: 0.11,
      color: Color(0xFFCCFFF7),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final base = min(screenW, screenH);
    // Same loop math as the background capture: integer cycle counts
    // guarantee a seamless return to the initial position at t == 1.
    final tau = t * 2.0 * pi;

    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: _specs.map((spec) {
          final bubbleSize = base * spec.sizeFactor;
          final baseX = screenW * spec.anchorX;
          final baseY = screenH * spec.anchorY;

          final primary = spec.speed;
          final dx =
              (sin((tau * primary) + spec.phase) * base * spec.wobbleX) +
              (cos((tau * (primary + 1)) + spec.phase * 0.8) *
                  base *
                  (spec.wobbleX * 0.75));
          final dy =
              (cos((tau * (primary + 2)) + spec.phase * 1.1) *
                  base *
                  spec.wobbleY) +
              (sin((tau * (primary + 1)) + spec.phase * 0.6) *
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
                color: spec.color.withValues(alpha: spec.alpha),
                boxShadow: [
                  BoxShadow(
                    color: spec.color.withValues(alpha: spec.alpha * 0.75),
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

  final double sizeFactor;
  final double anchorX;
  final double anchorY;
  final double phase;
  final double speed;
  final double alpha;
  final double wobbleX;
  final double wobbleY;
  final Color color;
}

class _IrisRevealOverlayPainter extends CustomPainter {
  const _IrisRevealOverlayPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final eased = Curves.easeInOutCubic.transform(progress.clamp(0.0, 1.0));
    final maxRadius = sqrt(
      (size.width * size.width) + (size.height * size.height),
    );
    final radius = lerpDouble(0.0, maxRadius, eased)!;

    canvas.saveLayer(rect, Paint());
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.black.withValues(alpha: lerpDouble(1.0, 0.0, eased)!),
    );

    canvas.drawCircle(
      rect.center,
      radius,
      Paint()
        ..blendMode = BlendMode.clear
        ..color = Colors.transparent,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _IrisRevealOverlayPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
