import 'dart:math';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

/// Widgets reutilizables (para splash y login) + painters.
/// Así NO duplicamos el mega-código.

class DicsaLogoD extends StatelessWidget {
  const DicsaLogoD({
    super.key,
    required this.size,
    this.progress = 1.0, // 1 = lleno
    this.penFrac = 0.10,
  });

  final double size;
  final double progress;
  final double penFrac;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: DRevealStrokeThenFillPainter(
          progress: progress,
          penFrac: penFrac,
        ),
      ),
    );
  }
}

class DicsaWordMark extends StatelessWidget {
  const DicsaWordMark({
    super.key,
    required this.width,
    required this.height,
    this.progress = 1.0,
    this.penFrac = 0.08,
  });

  final double width;
  final double height;
  final double progress;
  final double penFrac;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: WordRevealFillAlongOutlinePainter(
          progress: progress,
          penFrac: penFrac,
        ),
      ),
    );
  }
}

class DicsaSvgPaths {
  static const blue = Color(0xFF0086FF);
  static const green = Color(0xFF13D183);
  static const word = Color(0xFF304151);

  static const String blueD = r'''
M297.8,223.49h-81.01v-108.51h13.66v94.85h67.35c37.13,0,67.35-30.21,67.35-67.35s-30.21-67.35-67.35-67.35h-81.01v-13.66h81.01c44.67,0,81.01,36.34,81.01,81.01s-36.34,81.01-81.01,81.01Z
''';

  static const String greenD = r'''
M297.8,196.81h-54.19v-13.66h54.19c22.43,0,40.67-18.25,40.67-40.67s-18.25-40.67-40.67-40.67h-94.01v88.18h-13.66v-101.84h107.67c29.96,0,54.34,24.37,54.34,54.34s-24.37,54.34-54.34,54.34Z
''';

  static const List<String> wordPaths = [
    r'''M422.96,212.5c-.81,0-1.62-.81-1.62-1.62l.81-69.94-.81-68.32c0-.81.81-1.62,1.62-1.62h47.5c40.63,0,73.17,23.04,73.17,71.35s-33.96,70.14-72.77,70.14h-47.91ZM446.6,193.09h25.87c23.85,0,45.68-14.76,45.68-50.94s-20.62-51.75-46.49-51.75h-25.06c0,.2-.61,31.33-.61,49.93s.61,52.55.61,52.76Z''',
    r'''M554.74,97.68c-.81,0-1.62-.81-1.62-1.62v-20.82c0-.81.81-1.62,1.62-1.62h21.43c.81,0,1.62.81,1.62,1.62v20.82c0,.81-.81,1.62-1.62,1.62h-21.43ZM554.74,212.5c-.81,0-1.62-.81-1.62-1.62l.4-51.14-.4-49.72c0-.81.81-1.62,1.62-1.62h21.63c.81,0,1.62.81,1.62,1.62l-.61,49.72.61,51.14c0,.81-.81,1.62-1.62,1.62h-21.63Z''',
    r'''M638.02,214.92c-32.34,0-50.94-21.22-50.94-54.17s18.6-54.78,51.34-54.78c26.28,0,42.85,14.96,45.08,37.4.2.81-.61,1.62-1.42,1.62h-19.2c-.81,0-1.62-.61-1.82-1.62-2.43-13.34-11.12-20.01-22.64-20.01-17.99,0-26.48,12.94-26.48,37.19s8.69,36.99,26.48,37.19c13.14.2,22.23-8.29,23.45-23.25.2-1.01,1.01-1.62,1.82-1.62h19.81c.81,0,1.62.81,1.41,1.62-2.02,23.45-19.81,40.43-46.89,40.43Z''',
    r'''M738.07,214.92c-29.31,0-47.7-12.33-48.51-36.18,0-.81.81-1.62,1.62-1.62h20.42c.81,0,1.62.81,1.62,1.62.61,13.75,9.5,20.01,25.87,20.01,13.75,0,22.03-5.46,22.03-15.16,0-23.04-69.13-2.63-69.13-45.48,0-21.02,16.78-32.14,43.26-32.14s43.86,10.71,45.48,32.54c0,.81-.81,1.62-1.62,1.62h-19.4c-.81,0-1.62-.61-1.82-1.62-1.62-10.71-9.3-16.78-23.04-16.78-11.93,0-19.61,4.45-19.61,14.55,0,22.44,69.13,1.21,69.13,45.28,0,21.22-19.81,33.35-46.29,33.35Z''',
    r'''M867.03,212.5c-.81,0-1.62-.81-1.62-1.62l.4-12.73c-7.07,10.31-17.99,16.37-31.94,16.37-28.91,0-44.06-23.45-44.06-53.77s16.57-54.37,44.47-54.37c13.75,0,24.46,5.26,31.53,15.36l-.61-11.72c0-.81.81-1.62,1.62-1.62h21.43c.81,0,1.62.81,1.62,1.62l-.61,50.13.61,50.74c0,.81-.81,1.62-1.62,1.62h-21.22ZM840.35,197.34c16.37,0,25.87-12.13,26.08-36.18s-9.1-37.39-25.47-37.6c-17.79-.2-26.48,13.34-26.48,35.58,0,24.26,8.89,38.2,25.87,38.2Z'''
  ];
}

class _Fit {
  static Path fitToHeight(Path raw, Size size) {
    final b = raw.getBounds();
    final scale = size.height / b.height;
    final dx = -b.left * scale;
    final dy = (size.height - b.height * scale) / 2 - b.top * scale;
    final m = Matrix4.translationValues(dx, dy, 0) * Matrix4.diagonal3Values(scale, scale, 1);
    return raw.transform(m.storage);
  }
}

double _bestStartOffsetFrac(Path path, Offset anchor, {int samples = 240}) {
  final metrics = path.computeMetrics().toList();
  if (metrics.isEmpty) return 0.0;

  final totalLen = metrics.fold<double>(0.0, (s, m) => s + m.length);
  if (totalLen <= 0) return 0.0;

  double bestFrac = 0.0;
  double bestDist = double.infinity;

  for (int i = 0; i <= samples; i++) {
    final frac = i / samples;
    final target = totalLen * frac;

    double walked = 0.0;
    for (final m in metrics) {
      if (walked + m.length >= target) {
        final local = target - walked;
        final tan = m.getTangentForOffset(local);
        if (tan != null) {
          final d = (tan.position - anchor).distanceSquared;
          if (d < bestDist) {
            bestDist = d;
            bestFrac = frac;
          }
        }
        break;
      }
      walked += m.length;
    }
  }
  return bestFrac;
}

Path _extractPartialPathCircular(Path path, double t,
    {double startOffsetFrac = 0.0}) {
  final metrics = path.computeMetrics().toList();
  if (metrics.isEmpty) return Path();

  final totalLen = metrics.fold<double>(0.0, (s, m) => s + m.length);
  if (totalLen <= 0) return Path();

  final targetLen = (totalLen * t.clamp(0.0, 1.0)).clamp(0.0, totalLen);
  final startShift = (totalLen * startOffsetFrac).clamp(0.0, totalLen);

  final out = Path();
  double need = targetLen;

  double walked = 0.0;
  for (final m in metrics) {
    final len = m.length;
    if (walked + len < startShift) {
      walked += len;
      continue;
    }
    final localStart = max(0.0, startShift - walked);
    final canTake = min(len - localStart, need);
    if (canTake > 0) {
      out.addPath(m.extractPath(localStart, localStart + canTake), Offset.zero);
      need -= canTake;
      if (need <= 0) break;
    }
    walked += len;
  }

  if (need > 0) {
    for (final m in metrics) {
      final canTake = min(m.length, need);
      if (canTake > 0) {
        out.addPath(m.extractPath(0, canTake), Offset.zero);
        need -= canTake;
        if (need <= 0) break;
      }
    }
  }

  return out;
}

void _drawFillRevealedByOutline({
  required Canvas canvas,
  required Path fillPath,
  required Color color,
  required double progress,
  required double penWidthPx,
  required double startOffsetFrac,
  StrokeCap cap = StrokeCap.round,
  StrokeJoin join = StrokeJoin.round,
}) {
  final t = progress.clamp(0.0, 1.0);
  if (t <= 0.000001) return;

  final metrics = fillPath.computeMetrics().toList();
  if (metrics.isEmpty) return;

  final totalLen = metrics.fold<double>(0.0, (s, m) => s + m.length);
  final targetLen = totalLen * t;
  final startShift = (totalLen * startOffsetFrac).clamp(0.0, totalLen);

  final outlinePartial = Path();
  double need = targetLen;

  double walked = 0.0;
  for (final m in metrics) {
    final len = m.length;
    if (walked + len < startShift) {
      walked += len;
      continue;
    }
    final localStart = max(0.0, startShift - walked);
    final canTake = min(len - localStart, need);
    if (canTake > 0) {
      outlinePartial.addPath(
          m.extractPath(localStart, localStart + canTake), Offset.zero);
      need -= canTake;
      if (need <= 0) break;
    }
    walked += len;
  }

  if (need > 0) {
    for (final m in metrics) {
      final canTake = min(m.length, need);
      if (canTake > 0) {
        outlinePartial.addPath(m.extractPath(0, canTake), Offset.zero);
        need -= canTake;
        if (need <= 0) break;
      }
    }
  }

  canvas.saveLayer(null, Paint());
  canvas.drawPath(fillPath, Paint()..style = PaintingStyle.fill..color = color);

  final maskPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = penWidthPx
    ..strokeCap = cap
    ..strokeJoin = join
    ..blendMode = BlendMode.dstIn
    ..color = Colors.white;

  canvas.drawPath(outlinePartial, maskPaint);
  canvas.restore();
}

class DRevealStrokeThenFillPainter extends CustomPainter {
  final double progress; // 0..1
  final double penFrac;

  const DRevealStrokeThenFillPainter({
    required this.progress,
    required this.penFrac,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final blueRaw = parseSvgPathData(DicsaSvgPaths.blueD);
    final greenRaw = parseSvgPathData(DicsaSvgPaths.greenD);

    final bb = blueRaw.getBounds();
    final gb = greenRaw.getBounds();
    final bounds = bb.expandToInclude(gb);

    final scale = min(size.width / bounds.width, size.height / bounds.height);
    final dx = (size.width - bounds.width * scale) / 2 - bounds.left * scale;
    final dy = (size.height - bounds.height * scale) / 2 - bounds.top * scale;

    final m = Matrix4.translationValues(dx, dy, 0) * Matrix4.diagonal3Values(scale, scale, 1);

    final blue = blueRaw.transform(m.storage);
    final green = greenRaw.transform(m.storage);

    final b = blue.getBounds();
    final g = green.getBounds();

    final strokeT =
        Curves.easeInOut.transform(((progress - 0.00) / 0.78).clamp(0.0, 1.0));
    final fillT =
        Curves.easeInOut.transform(((progress - 0.72) / 0.28).clamp(0.0, 1.0));

    final strokeW = max(2.5, size.width * penFrac * 0.12);

    final greenAnchor = Offset(g.left, g.bottom);
    final blueAnchor = Offset(b.right, b.top);

    final greenStart = _bestStartOffsetFrac(green, greenAnchor);
    final blueStart = _bestStartOffsetFrac(blue, blueAnchor);

    final gStroke =
        Curves.easeInOut.transform(((strokeT - 0.00) / 1.00).clamp(0.0, 1.0));
    final bStroke =
        Curves.easeInOut.transform(((strokeT - 0.05) / 0.95).clamp(0.0, 1.0));

    final bluePartial =
        _extractPartialPathCircular(blue, bStroke, startOffsetFrac: blueStart);
    final greenPartial =
        _extractPartialPathCircular(green, gStroke, startOffsetFrac: greenStart);

    final strokeOpacity = (1.0 - fillT).clamp(0.0, 1.0);

    final blueStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = DicsaSvgPaths.blue.withAlpha((strokeOpacity * 255).round());

    final greenStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = DicsaSvgPaths.green.withAlpha((strokeOpacity * 255).round());

    canvas.drawPath(bluePartial, blueStrokePaint);
    canvas.drawPath(greenPartial, greenStrokePaint);

    if (fillT > 0) {
      canvas.drawPath(
        blue,
        Paint()
          ..style = PaintingStyle.fill
          ..color = DicsaSvgPaths.blue.withAlpha((fillT * 255).round()),
      );
      canvas.drawPath(
        green,
        Paint()
          ..style = PaintingStyle.fill
          ..color = DicsaSvgPaths.green.withAlpha((fillT * 255).round()),
      );
    }
  }

  @override
  bool shouldRepaint(covariant DRevealStrokeThenFillPainter old) =>
      old.progress != progress || old.penFrac != penFrac;
}

class WordRevealFillAlongOutlinePainter extends CustomPainter {
  final double progress; // 0..1
  final double penFrac;

  const WordRevealFillAlongOutlinePainter({
    required this.progress,
    required this.penFrac,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final combined = Path();
    for (final d in DicsaSvgPaths.wordPaths) {
      combined.addPath(parseSvgPathData(d), Offset.zero);
    }

    final p = _Fit.fitToHeight(combined, size);
    final b = p.getBounds();

    final t = progress.clamp(0.0, 1.0);

    final centerX = b.center.dx;
    final minHalfWidth = b.width * 0.0003;
    final halfWidth =
        lerpDouble(minHalfWidth, b.width / 2, Curves.easeInOut.transform(t))!;

    final clipRect = Rect.fromLTRB(
      centerX - halfWidth,
      b.top - 10,
      centerX + halfWidth,
      b.bottom + 10,
    );

    canvas.save();
    canvas.clipRect(clipRect);

    final pen = max(3.0, size.height * penFrac);
    final anchor = Offset(centerX, b.center.dy);
    final start = _bestStartOffsetFrac(p, anchor);

    _drawFillRevealedByOutline(
      canvas: canvas,
      fillPath: p,
      color: DicsaSvgPaths.word,
      progress: t,
      penWidthPx: pen,
      startOffsetFrac: start,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WordRevealFillAlongOutlinePainter old) =>
      old.progress != progress || old.penFrac != penFrac;
}