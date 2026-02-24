import 'dart:math';

import 'package:flutter/material.dart';

void main() {
  runApp(const _BackgroundBlobsRecordingApp());
}

class _BackgroundBlobsRecordingApp extends StatelessWidget {
  const _BackgroundBlobsRecordingApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BackgroundBlobsRecordingScreen(),
    );
  }
}

class BackgroundBlobsRecordingScreen extends StatefulWidget {
  const BackgroundBlobsRecordingScreen({super.key});

  @override
  State<BackgroundBlobsRecordingScreen> createState() =>
      _BackgroundBlobsRecordingScreenState();
}

class _BackgroundBlobsRecordingScreenState
    extends State<BackgroundBlobsRecordingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 16))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          return LayoutBuilder(
            builder: (_, cts) => _BlobsBackdrop(
              t: _c.value,
              screenW: cts.maxWidth,
              screenH: cts.maxHeight,
            ),
          );
        },
      ),
    );
  }
}

class _BlobsBackdrop extends StatelessWidget {
  const _BlobsBackdrop({
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
          child: _BlobsLayer(t: t, screenW: screenW, screenH: screenH),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.08),
                  radius: 1.08,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.10),
                    Colors.black.withValues(alpha: 0.26),
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

class _BlobsLayer extends StatelessWidget {
  const _BlobsLayer({
    required this.t,
    required this.screenW,
    required this.screenH,
  });

  final double t;
  final double screenW;
  final double screenH;

  static const List<_BubbleSpec> _specs = [
    _BubbleSpec(
      sizeFactor: 0.92,
      anchorX: 0.07,
      anchorY: 0.14,
      phase: 0.2,
      speed: 2,
      alpha: 0.24,
      wobbleX: 0.06,
      wobbleY: 0.19,
      color: Color(0xFFECFEFF),
    ),
    _BubbleSpec(
      sizeFactor: 0.76,
      anchorX: 0.90,
      anchorY: 0.16,
      phase: 1.1,
      speed: 3,
      alpha: 0.20,
      wobbleX: 0.07,
      wobbleY: 0.18,
      color: Color(0xFFD6FFF2),
    ),
    _BubbleSpec(
      sizeFactor: 0.86,
      anchorX: 0.52,
      anchorY: 0.45,
      phase: 2.3,
      speed: 2,
      alpha: 0.16,
      wobbleX: 0.06,
      wobbleY: 0.20,
      color: Color(0xFFDDFEFF),
    ),
    _BubbleSpec(
      sizeFactor: 1.02,
      anchorX: 0.13,
      anchorY: 0.88,
      phase: 3.4,
      speed: 1,
      alpha: 0.20,
      wobbleX: 0.05,
      wobbleY: 0.15,
      color: Color(0xFFFFFFFF),
    ),
    _BubbleSpec(
      sizeFactor: 0.72,
      anchorX: 0.86,
      anchorY: 0.83,
      phase: 4.2,
      speed: 2,
      alpha: 0.18,
      wobbleX: 0.06,
      wobbleY: 0.14,
      color: Color(0xFFCCFFF7),
    ),
    _BubbleSpec(
      sizeFactor: 0.58,
      anchorX: 0.72,
      anchorY: 0.32,
      phase: 5.6,
      speed: 4,
      alpha: 0.14,
      wobbleX: 0.04,
      wobbleY: 0.11,
      color: Color(0xFFF2FFFF),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final base = min(screenW, screenH);
    // tau completes exactly one turn when t goes 0 -> 1, so using integer
    // cycle counts below makes the loop close seamlessly.
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
                  (spec.wobbleX * 0.8));
          final dy =
              (cos((tau * (primary + 2)) + spec.phase * 1.1) *
                  base *
                  spec.wobbleY) +
              (sin((tau * (primary + 1)) + spec.phase * 0.6) *
                  base *
                  (spec.wobbleY * 0.65));

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
                    color: spec.color.withValues(alpha: spec.alpha * 0.72),
                    blurRadius: bubbleSize * 0.22,
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
