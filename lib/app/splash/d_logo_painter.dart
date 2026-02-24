import 'dart:math';
import 'package:flutter/material.dart';

class DLogoPainter extends CustomPainter {
  final double progress; // 0..1
  final Color blue;
  final Color green;

  DLogoPainter({
    required this.progress,
    this.blue = const Color(0xFF137BFF),
    this.green = const Color(0xFF1ECF7A),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);

    // Tamaño base del logo (ajústalo si lo quieres más grande/chico)
    final logoW = min(size.width, size.height) * 0.28; // ancho total aproximado
    final logoH = logoW; // la D es casi cuadrada en tu imagen

    // Grosor del trazo
    final stroke = logoW * 0.10;

    // Separación entre azul y verde (en tu logo hay un “offset”)
    final offset = stroke * 0.55;

    // Radio de la curva derecha (es clave para que se vea como tu D)
    final r = logoW * 0.42;

    // Rect base del logo (centrado)
    final outerRect = Rect.fromCenter(
      center: c,
      width: logoW,
      height: logoH,
    );

    // Path azul (exterior)
    final bluePath = _buildDPath(
      rect: outerRect,
      radiusRight: r,
      // “recortes” para que se parezca al estilo del logo (esquinas marcadas)
      topCut: stroke * 0.2,
      bottomCut: stroke * 0.2,
    );

    // Path verde (interior): inset + leve desplazamiento
    final greenRect = outerRect
        .deflate(stroke * 0.55)
        .translate(offset * 0.25, offset * 0.05);

    final greenPath = _buildDPath(
      rect: greenRect,
      radiusRight: r - stroke * 0.60,
      topCut: stroke * 0.1,
      bottomCut: stroke * 0.1,
    );

    // Animación: verde un poquito antes, azul después (se ve pro)
    final gP = _easeInOut(min(1.0, progress / 0.92));
    final bP = _easeInOut(max(0.0, (progress - 0.08) / 0.92));

    _drawTrimmed(canvas, greenPath, green, stroke, gP);
    _drawTrimmed(canvas, bluePath, blue, stroke, bP);
  }

  Path _buildDPath({
    required Rect rect,
    required double radiusRight,
    required double topCut,
    required double bottomCut,
  }) {
    final left = rect.left;
    final top = rect.top;
    final right = rect.right;
    final bottom = rect.bottom;

    // Punto donde empieza la curva derecha
    final curveStartX = right - radiusRight;

    // Para que quede estilo “esquinas marcadas”, hacemos cortes chiquitos
    final yTop = top + topCut;
    final yBottom = bottom - bottomCut;

    final p = Path();

    // Arranque: esquina superior izquierda (un poco abajo por el corte)
    p.moveTo(left, yTop);

    // Subimos a top (esquina marcada)
    p.lineTo(left, top);

    // Horizontal superior hasta antes de curva derecha
    p.lineTo(curveStartX, top);

    // Curva derecha (de top a bottom)
    p.arcToPoint(
      Offset(curveStartX, bottom),
      radius: Radius.circular(radiusRight),
      clockwise: true,
    );

    // Horizontal inferior hacia la izquierda
    p.lineTo(left, bottom);

    // Subimos un poquito para formar el “corte” de esquina inferior
    p.lineTo(left, yBottom);

    // Regresamos hacia arriba al punto inicial (cierra la forma del trazo)
    p.lineTo(left, yTop);

    return p;
  }

  void _drawTrimmed(Canvas canvas, Path path, Color color, double strokeWidth, double t) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square // esquinas más “definidas” como tu logo
      ..strokeJoin = StrokeJoin.miter
      ..color = color;

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final total = metrics.fold<double>(0, (s, m) => s + m.length);
    final target = total * t;

    var drawn = 0.0;
    final out = Path();

    for (final m in metrics) {
      final remain = target - drawn;
      if (remain <= 0) break;
      final len = min(m.length, remain);
      out.addPath(m.extractPath(0, len), Offset.zero);
      drawn += len;
    }

    canvas.drawPath(out, paint);
  }

  double _easeInOut(double x) {
    // suave tipo “cinemático”
    return x * x * (3 - 2 * x);
  }

  @override
  bool shouldRepaint(covariant DLogoPainter oldDelegate) => oldDelegate.progress != progress;
}